<?php
@session_start();

require_once __DIR__ . '/../../../vendor/autoload.php';
require_once __DIR__ . '/../../../lib/lti/db.php';
require_once __DIR__ . '/../../../lib/hub-const.php';
require_once __DIR__ . '/../../../lib/functions.php';

use \IMSGlobal\LTI;

$launch = null;
try {
    $launch = LTI\LTI_Message_Launch::new(new CoursewareHub_Database())
        ->validate();
} catch (Exception $e) {
    error_log("LTI Login failed: $e");
    error_page(
        "Not Authorized",
        "This tool provider is not available from the link you clicked.");
    http_response_code(403);
    exit;
}

$launch_data = $mail_address = $launch->get_launch_data();
$issuer = $launch_data['iss'];
if (!isset($launch_data['email'])) {
    error_log("Could not receive email address: issuer=$issuer");
    error_page(
        "Not Authorized",
        "Could not receive your email address from $issuer.");
    http_response_code(400);
    exit;
}

$mail_address = $launch_data['email'];

if ($launch->is_resource_launch()) {
    session_regenerate_id(true);
    $username = get_username_from_mail_address($mail_address);
    $_SESSION['username'] = $username;
    $_SESSION['authtype'] = 'lti';
    $_SESSION['iss'] = $issuer;

    $data = $custom = $launch->get_launch_data();
    $custom_key = 'https://purl.imsglobal.org/spec/lti/claim/custom';
    $notebook = null;
    if (isset($data[$custom_key])) {
        $custom = $data[$custom_key];
        if (isset($custom['notebook'])) {
            $notebook = $custom['notebook'];
        }
        if (isset($custom['logout-redirect-url'])) {
            $logout_redirect_url = $custom['logout-redirect-url'];
            $logout_redirect_url = filter_var($logout_redirect_url, FILTER_UNSAFE_RAW,
                                              FILTER_FLAG_ENCODE_HIGH | FILTER_FLAG_ENCODE_LOW);
            $_SESSION['logout-redirect-url'] = $logout_redirect_url;
        }
    }
    header("X-Accel-Redirect: /entrance/");
    if ($notebook) {
        $notebook = rawurlencode($notebook);
        header("X-Reproxy-URL: ".HUB_URL.'/'.COURSE_NAME."/hub/login?next=/user-redirect/notebooks/".$notebook);
    } else {
        header("X-Reproxy-URL: ".HUB_URL.'/'.COURSE_NAME."/hub/login");
    }
    header("X-REMOTE-USER: $username");
} else if ($launch->is_deep_link_launch()) {
    error_log('Deep linking launch type');
    error_page(
        "Unsupported launch type",
        "This tool provider is not support deep linking launch.");
    http_response_code(400);
} else {
    error_log('Unknown launch type');
    error_page("Unknown launch type", "");
    http_response_code(400);
}

?>
