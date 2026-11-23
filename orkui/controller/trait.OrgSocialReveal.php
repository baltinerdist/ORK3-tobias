<?php

/**
 * Anti-harvest reveal for org social links (Kingdom / Park / Unit "Connect").
 *
 * Social URLs, a Discord invite above all, are scraper bait: a harvested
 * invite gets spammed or raided. So the URLs are never in page HTML or in a
 * public read (the domain publishes only the platform slugs). A visitor's
 * click asks the server for that one link, and the server only answers when:
 *
 *   1. it is a same-origin POST made by script (X-Requested-With), so a link
 *      crawler that just follows hrefs never gets here;
 *   2. the User-Agent is not an obvious bot / HTTP library / headless browser;
 *   3. it carries the random token this visitor's PHP session was issued when
 *      the profile page rendered, and that token is at least a second old (a
 *      cookie-less scraper gets a fresh session every request, so its token
 *      never matches; a script that posts the instant the page loads fails
 *      the age check);
 *   4. the client IP and the session are under a rolling rate limit.
 *
 * A headless browser that keeps cookies and clicks every pill slowly can still
 * get through: the point is to make bulk harvesting slow, noisy and capped.
 *
 * Used by the page controllers (org_social_reveal_token, issue) and the *Ajax
 * controllers (org_social_reveal, answer; reachable without logging in).
 */
trait OrgSocialReveal
{
    /** Token lifetime, and how old one may get before a page view replaces it. */
    private static $odSocialTokenTtl   = 14400; // 4 h
    private static $odSocialTokenRenew = 3600;  // 1 h
    /** Rolling-window caps: reveals per client IP, and per session. */
    private static $odSocialIpLimit      = 30;
    private static $odSocialSessionLimit = 15;
    private static $odSocialWindow       = 600; // 10 min

    /**
     * The reveal token for this session + org, issued (or renewed) on a page
     * view. The previous token stays valid so an already-open tab keeps working.
     */
    protected function org_social_reveal_token(string $org, int $id): string
    {
        if (session_status() !== PHP_SESSION_ACTIVE) {
            return '';
        }
        $key = $org . ':' . $id;
        $now = time();
        $cur = $_SESSION['od_social'][$key] ?? null;
        if (is_array($cur) && isset($cur['t'], $cur['at']) && ($now - (int)$cur['at']) < self::$odSocialTokenRenew) {
            return (string)$cur['t'];
        }
        $_SESSION['od_social'][$key] = [
            't'    => bin2hex(random_bytes(16)),
            'at'   => $now,
            'prev' => is_array($cur) ? ['t' => (string)($cur['t'] ?? ''), 'at' => (int)($cur['at'] ?? 0)] : null,
        ];
        return $_SESSION['od_social'][$key]['t'];
    }

    /**
     * Answer a reveal request with {status:0,url} or an error, then exit.
     *
     * @param object $model  The loaded org model.
     * @param string $method Model method returning one URL: (int $id, string $slug) => string.
     */
    protected function org_social_reveal(object $model, string $method, string $org, int $id): void
    {
        header('Content-Type: application/json');
        header('Cache-Control: no-store, private');
        header('X-Robots-Tag: noindex, nofollow');

        $fail = function (int $http, string $msg): void {
            http_response_code($http);
            echo json_encode(['status' => 1, 'error' => $msg]);
            exit;
        };

        if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST'
            || strtolower((string)($_SERVER['HTTP_X_REQUESTED_WITH'] ?? '')) !== 'xmlhttprequest'
            || !self::org_social_same_origin()) {
            $fail(403, 'Open this link from the profile page.');
        }
        if (self::org_social_is_bot()) {
            $fail(403, 'Links are not available to automated clients.');
        }
        // Count every attempt against the IP, valid or not, so token guessing is capped too.
        if (!self::org_social_rate_ok('ip.' . self::org_social_client_ip(), self::$odSocialIpLimit)) {
            $fail(429, 'Too many links opened. Please wait a few minutes and try again.');
        }
        if (!valid_id($id)) {
            $fail(400, 'Unknown profile.');
        }
        $slug = (string)($_POST['Platform'] ?? '');
        if (!preg_match('/^[a-z]{2,20}$/', $slug)) {
            $fail(400, 'Unknown link.');
        }
        if (!$this->org_social_token_ok($org . ':' . $id, (string)($_POST['RevealToken'] ?? ''))) {
            $fail(403, 'This page has expired. Reload it and try again.');
        }
        if (!self::org_social_rate_ok('sess.' . session_id(), self::$odSocialSessionLimit)) {
            $fail(429, 'Too many links opened. Please wait a few minutes and try again.');
        }

        $url = (string)$model->$method($id, $slug);
        if ($url === '' || !preg_match('#^https://#i', $url)) {
            $fail(404, 'That link is no longer available.');
        }
        echo json_encode(['status' => 0, 'url' => $url]);
        exit;
    }

    private function org_social_token_ok(string $key, string $token): bool
    {
        if ($token === '' || session_status() !== PHP_SESSION_ACTIVE) {
            return false;
        }
        $rec = $_SESSION['od_social'][$key] ?? null;
        if (!is_array($rec)) {
            return false;
        }
        $now = time();
        foreach ([$rec, $rec['prev'] ?? null] as $cand) {
            if (!is_array($cand) || empty($cand['t'])) {
                continue;
            }
            $age = $now - (int)$cand['at'];
            if ($age >= 1 && $age <= self::$odSocialTokenTtl && hash_equals((string)$cand['t'], $token)) {
                return true;
            }
        }
        return false;
    }

    /** Origin (or, failing that, Referer) must name this host. */
    private static function org_social_same_origin(): bool
    {
        $host = strtolower((string)($_SERVER['HTTP_HOST'] ?? ''));
        $src  = (string)($_SERVER['HTTP_ORIGIN'] ?? ($_SERVER['HTTP_REFERER'] ?? ''));
        if ($host === '' || $src === '') {
            return false;
        }
        $srcHost = strtolower((string)parse_url($src, PHP_URL_HOST));
        $srcPort = parse_url($src, PHP_URL_PORT);
        $srcFull = $srcPort ? $srcHost . ':' . $srcPort : $srcHost;
        return $srcFull === $host || ($srcPort === null && $srcHost === explode(':', $host)[0]);
    }

    private static function org_social_is_bot(): bool
    {
        $ua = (string)($_SERVER['HTTP_USER_AGENT'] ?? '');
        if (trim($ua) === '') {
            return true;
        }
        return (bool)preg_match(
            '/bot\b|bot\/|crawl|spider|slurp|scrap|archiver|facebookexternalhit|embedly|preview|'
            . 'curl|wget|python|httpclient|http-client|okhttp|java\/|go-http|libwww|aiohttp|axios|node-fetch|'
            . 'headless|phantomjs|puppeteer|playwright|selenium/i',
            $ua
        );
    }

    /**
     * Client IP behind Cloudflare + the host proxy (REMOTE_ADDR is the docker
     * bridge there, the same for every visitor). Same order as the login
     * session metadata: CF-Connecting-IP, first X-Forwarded-For hop, REMOTE_ADDR.
     */
    private static function org_social_client_ip(): string
    {
        $ip = (string)($_SERVER['HTTP_CF_CONNECTING_IP'] ?? '');
        if ($ip === '' && !empty($_SERVER['HTTP_X_FORWARDED_FOR'])) {
            $ip = trim(explode(',', (string)$_SERVER['HTTP_X_FORWARDED_FOR'])[0]);
        }
        if ($ip === '') {
            $ip = (string)($_SERVER['REMOTE_ADDR'] ?? '');
        }
        return substr($ip, 0, 45);
    }

    /**
     * Rolling-window counter in memcache. Fails open when memcache is down:
     * the session token still gates every reveal.
     */
    private static function org_social_rate_ok(string $bucket, int $limit): bool
    {
        if (!class_exists('Memcached')) {
            return true;
        }
        static $mc = null;
        if ($mc === null) {
            $mc = new Memcached();
            $mc->addServer('localhost', 11211);
        }
        $prefix = defined('CACHE_HOST') ? CACHE_HOST : ($_SERVER['HTTP_HOST'] ?? 'ork');
        $key = $prefix . '.odsocial.' . md5($bucket);
        $n = $mc->increment($key);
        if ($n === false) {
            if (!$mc->add($key, 1, self::$odSocialWindow)) {
                $n = $mc->increment($key);
                if ($n === false) {
                    return true; // memcache unavailable
                }
            } else {
                $n = 1;
            }
        }
        return $n <= $limit;
    }
}
