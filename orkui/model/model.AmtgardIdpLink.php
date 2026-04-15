<?php

class Model_AmtgardIdpLink extends Model {
	function __construct() {
		parent::__construct();
	}

	/**
	 * Mirror an ORK profile link back to bastion-idp.
	 * Confidential-client authenticated POST to /resources/link-ork-profile.
	 * Returns true on 2xx, false on any other outcome.
	 */
	public function linkOrkProfile($idpUserId, $mundaneId)
	{
		$ch = curl_init();
		curl_setopt($ch, CURLOPT_URL, IDP_API_URL . '/resources/link-ork-profile');
		curl_setopt($ch, CURLOPT_POST, 1);
		curl_setopt($ch, CURLOPT_HTTPHEADER, [
			'Content-Type: application/json',
			'Accept: application/json',
			'Authorization: Basic ' . base64_encode(IDP_CLIENT_ID . ':' . IDP_CLIENT_SECRET),
		]);
		curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode([
			'idp_user_id' => $idpUserId,
			'mundane_id'  => (int)$mundaneId,
		]));
		curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
		curl_setopt($ch, CURLOPT_TIMEOUT, 5);
		curl_setopt($ch, CURLOPT_USERAGENT, 'AmtgardORK/1.0');
		$body = curl_exec($ch);
		$http = curl_getinfo($ch, CURLINFO_HTTP_CODE);
		$err  = curl_error($ch);
		curl_close($ch);

		if ($http >= 200 && $http < 300) {
			return true;
		}
		error_log("Model_AmtgardIdpLink::linkOrkProfile failed http=$http err=$err body=$body");
		return false;
	}
}
