<?php

class Controller_Login extends Controller {

	public function __construct($call = null, $method = null) {
		parent::__construct($call, $method);
        $this->load_model('AmtgardIdp');
		$this->data['page_title'] = 'Login';
	}

	public function index($action = null) {
		$this->template = '../revised-frontend/Login_index.tpl';
		if (($_GET['msg'] ?? '') === 'session_replaced') {
			$this->data['session_message'] = 'You were logged in from another device or browser. Please log in again.';
		}
	}

	public function logout($userid = null){
		$this->session->location = null;
		$this->Login->logout($userid);
		header('Location: ' . UIR);
	}

	public function login($location = null) {
		$this->template = '../revised-frontend/Login_index.tpl';
		if (($_GET['msg'] ?? '') === 'session_replaced') {
			$this->data['session_message'] = 'You were logged in from another device or browser. Please log in again.';
		}
		if (strlen(trim($this->session->location)) == 0) {
			$this->session->location = $location;
		}

		if ((strlen($this->request->username) > 0 && strlen($this->request->password) > 0) && ($r = $this->Login->login($this->request->username, $this->request->password)) === true) {
			if ($this->session->location == null) {
				header('Location: ' . UIR);
			} else {
				//$this->session->location = null;
				header('Location: ' . UIR . $this->session->location);
			}
		} else {
			$this->data["error"] = $r['Status']['Error'];
			$this->data["detail"] = $r['Status']['Detail'];
		}
	}

	public function forgotpassword($recover = null) {
		$this->template = '../revised-frontend/Login_forgotpassword.tpl';
		if ($recover == 'recover') {
			if (($r = $this->Login->recover_password($_POST['username'], $_POST['email'])) === true) {
				$this->data["error"] = "A new password has been emailed to you. The new password will expire in 24 hours. Please log in and change your password immediately.";
				$this->data["detail"] = "";
			} else {
				$this->data["error"] = $r['Error'];
				$this->data["detail"] = $r['Detail'];
			}
		}
	}

	private function base64UrlEncode($data)
	{
		return rtrim(strtr(base64_encode($data), '+/', '-_'), '=');
	}

	public function login_oauth()
	{
		$code_verifier = $this->base64UrlEncode(random_bytes(32));
		$code_challenge = $this->base64UrlEncode(hash('sha256', $code_verifier, true));

		$this->session->code_verifier = $code_verifier;

		$query = http_build_query([
			'client_id' => IDP_CLIENT_ID,
			'redirect_uri' => UIR . 'Login/oauth_callback',
			'response_type' => 'code',
			'scope' => 'profile email',
			'code_challenge' => $code_challenge,
			'code_challenge_method' => 'S256',
		]);
		header('Location: ' . IDP_BASE_URL . '/oauth/authorize?' . $query);
		exit;
	}

	public function oauth_callback()
	{
		if (!isset($_GET['code'])) {
			$this->data['error'] = 'IDP did not return an authorization code.';
			$this->template = '../revised-frontend/Login_index.tpl';
			return;
		}

		$token_data = $this->AmtgardIdp->exchangeAuthCodeForAccessToken($_GET['code'], $this->session->code_verifier);

		if (isset($token_data['error'])) {
			error_log("Amtgard IDP OAuth callback: Token exchange failed");
			$this->data['error'] = "Couldn't exchange the IDP authorization code. Try again or use legacy login.";
			$this->template = '../revised-frontend/Login_index.tpl';
			return;
		}

		$user_data = $this->AmtgardIdp->fetchUserInfo($token_data['access_token']);

		if (isset($user_data['error'])) {
			error_log("Amtgard IDP OAuth callback: Failed to get user info: " . $user_data['response']);
			$this->data['error'] = "Couldn't reach Amtgard IDP. Try again or use legacy login.";
			$this->data['detail'] = $user_data['response'];
			$this->template = '../revised-frontend/Login_index.tpl';
			return;
		}

		// Stash the IDP context in the session for AuthorizeIdp + the claim flow.
		$this->session->IdpUserId    = $user_data['id'];
		$this->session->Email        = $user_data['email'] ?? '';
		$this->session->MundaneId    = isset($user_data['ork_profile']['mundane_id']) ? $user_data['ork_profile']['mundane_id'] : null;
		$this->session->AccessToken  = $token_data['access_token'];
		$this->session->RefreshToken = $token_data['refresh_token'] ?? null;
		$this->session->ExpiresAt    = time() + ($token_data['expires_in'] ?? 3600);

		$result = $this->Login->Authorization->AuthorizeIdp();

		// Auto-link / existing-link: log the user in and go to dashboard.
		if (isset($result['IdpResult']) && $result['IdpResult'] === Authorization::IDP_RESULT_LOGGED_IN
			&& isset($result['Status']['Status']) && $result['Status']['Status'] === 0) {
			$this->session->user_id  = $result['UserId'];
			$this->session->user_name = $result['UserName'];
			$this->session->token    = $result['Token'];
			$this->session->timeout  = $result['Timeout'];
			// Power-user opt-in: came in via the IDP button, set the autoredirect cookie.
			setcookie('ork_idp_autoredirect', '1', time() + 60 * 60 * 24 * 365, '/');
			header('Location: ' . UIR);
			return;
		}

		// Needs a manual claim — redirect to the claim form.
		if (isset($result['IdpResult']) && $result['IdpResult'] === Authorization::IDP_RESULT_NEEDS_CLAIM) {
			header('Location: ' . UIR . 'Login/claim_profile');
			return;
		}

		// Fallthrough: treat as failure.
		$this->data['error'] = $result['Status']['Error'] ?? 'Authentication failed';
		$this->data['detail'] = $result['Status']['Detail'] ?? '';
		$this->template = '../revised-frontend/Login_index.tpl';
	}

	public function claim_profile()
	{
		if (!isset($this->session->IdpUserId) || strlen($this->session->IdpUserId) === 0) {
			$this->data['error'] = 'Session expired — please start over.';
			$this->template = '../revised-frontend/Login_index.tpl';
			return;
		}
		$this->data['idp_email'] = $this->session->Email;
		$this->template = '../revised-frontend/Login_claim.tpl';
	}

	public function claim_submit()
	{
		if (!isset($this->session->IdpUserId) || strlen($this->session->IdpUserId) === 0) {
			$this->data['error'] = 'Session expired — please start over.';
			$this->template = '../revised-frontend/Login_index.tpl';
			return;
		}

		$username = trim($_POST['username'] ?? '');
		$password = $_POST['password'] ?? '';
		if (strlen($username) === 0 || strlen($password) === 0) {
			$this->data['idp_email'] = $this->session->Email;
			$this->data['error'] = 'Enter both your ORK username and password.';
			$this->template = '../revised-frontend/Login_claim.tpl';
			return;
		}

		$claim = [
			'IdpUserId'    => $this->session->IdpUserId,
			'Email'        => $this->session->Email,
			'AccessToken'  => $this->session->AccessToken,
			'RefreshToken' => $this->session->RefreshToken,
			'ExpiresAt'    => $this->session->ExpiresAt,
		];

		$result = $this->Login->Authorization->verifyClaimCredentials($username, $password, $claim);

		if (isset($result['Status']['Status']) && $result['Status']['Status'] === 0) {
			$this->session->user_id   = $result['UserId'];
			$this->session->user_name = $result['UserName'];
			$this->session->token     = $result['Token'];
			$this->session->timeout   = $result['Timeout'];
			setcookie('ork_idp_autoredirect', '1', time() + 60 * 60 * 24 * 365, '/');
			header('Location: ' . UIR);
			return;
		}

		$this->data['idp_email'] = $this->session->Email;
		$this->data['error'] = $result['Status']['Error'] ?? 'Username or password incorrect';
		$this->template = '../revised-frontend/Login_claim.tpl';
	}

	public function claim_request_magic_link()
	{
		if (!isset($this->session->IdpUserId) || strlen($this->session->IdpUserId) === 0) {
			$this->data['error'] = 'Session expired — please start over.';
			$this->template = '../revised-frontend/Login_index.tpl';
			return;
		}

		$username = trim($_POST['username'] ?? '');
		if (strlen($username) === 0) {
			$this->data['idp_email'] = $this->session->Email;
			$this->data['error'] = 'Enter your ORK username so we know where to send the link.';
			$this->template = '../revised-frontend/Login_claim.tpl';
			return;
		}

		$claim = [
			'IdpUserId' => $this->session->IdpUserId,
			'Email'     => $this->session->Email,
		];

		$issued = $this->Login->Authorization->issueClaimMagicLink($username, $claim);

		// Always show the same banner (no info disclosure on whether the username exists).
		$this->data['idp_email'] = $this->session->Email;
		$this->data['notice']    = 'If that username has an ORK account, we just emailed a one-time link to the address on file. Open it in this same browser to finish linking.';

		if ($issued !== false) {
			$link = UIR . 'Login/claim_magic_link?token=' . $issued['token'];
			$m = new Mail('smtp', AMAZON_SES_HOST, AMAZON_SES_USERNAME, AMAZON_SES_PASSWORD, 587);
			$m->setTo($issued['email']);
			$m->setFrom('ork3@amtgard.com');
			$m->setSender('ork3@amtgard.com');
			$m->setSubject('Connect your Amtgard ORK profile (link expires in 24 hours)');
			$m->setHtml(
				'<h2>Connect your ORK profile</h2>' .
				'You requested a one-time link to connect your ORK profile <b>' . htmlspecialchars($issued['username']) . '</b> ' .
				'to your Amtgard IDP account (' . htmlspecialchars($claim['Email']) . ').' .
				'<p><a href="' . $link . '">Click here to finish linking</a> — this link expires in 24 hours and works only once.' .
				'<p>If you did not request this, you can safely ignore this email.' .
				'<p>Regards,<br>-ORK Team'
			);
			$m->send();
		}

		$this->template = '../revised-frontend/Login_claim.tpl';
	}

	public function claim_magic_link()
	{
		$token = $_GET['token'] ?? '';
		$result = $this->Login->Authorization->consumeMagicLink($token);

		if (isset($result['Status']['Status']) && $result['Status']['Status'] === 0) {
			$this->session->user_id   = $result['UserId'];
			$this->session->user_name = $result['UserName'];
			$this->session->token     = $result['Token'];
			$this->session->timeout   = $result['Timeout'];
			setcookie('ork_idp_autoredirect', '1', time() + 60 * 60 * 24 * 365, '/');
			header('Location: ' . UIR);
			return;
		}

		$this->data['error'] = $result['Status']['Error'] ?? "That link isn't valid.";
		$this->template = '../revised-frontend/Login_index.tpl';
	}
}