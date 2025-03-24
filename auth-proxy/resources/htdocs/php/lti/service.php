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

$launch_data = $launch->get_launch_data();
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

    $custom_key = 'https://purl.imsglobal.org/spec/lti/claim/custom';
    $notebook = null;
    $server_name = null;
    $login_params = array();
    if (isset($launch_data[$custom_key])) {
        $custom = $launch_data[$custom_key];
        if (isset($custom['notebook'])) {
            $notebook = $custom['notebook'];
        }
        if (isset($custom['course_server'])) {
            $login_params['course_server'] = $custom['course_server'];
            $server_name = $custom['course_server'];
        }
        if (isset($custom['course_image'])) {
            $login_params['course_image'] = $custom['course_image'];
        }
        if (isset($custom['logout-redirect-url'])) {
            $logout_redirect_url = $custom['logout-redirect-url'];
            $logout_redirect_url = filter_var($logout_redirect_url, FILTER_UNSAFE_RAW,
                                              FILTER_FLAG_ENCODE_HIGH | FILTER_FLAG_ENCODE_LOW);
            $_SESSION['logout-redirect-url'] = $logout_redirect_url;
        }
    }
    $next = null;
    if ($notebook) {
        if ($server_name) {
             $next = "/user/".$username."/".$server_name."/notebooks/".$notebook;
        } else {
             $next = "/user/".$username."/notebooks/".$notebook;
        }
    }
    if ($server_name) {
        $spawn_url = '/hub/spawn/'.$username.'/'.$server_name;
        if ($next) {
            $query = http_build_query(['next' => $next], '', null, PHP_QUERY_RFC3986);
            $next = $spawn_url.'?'.$query;
        } else {
            $next = $spawn_url;
        }
    }
    if ($next) {
        $login_params['next'] = $next;
    }

    header("X-Accel-Redirect: /entrance/");
    $reproxy_url = HUB_URL.'/'.COURSE_NAME."/hub/login";
    $query = http_build_query($login_params, '', null, PHP_QUERY_RFC3986);
    if ($query) {
        $reproxy_url = $reproxy_url.'?'.$query;
    }
    header("X-Reproxy-URL: $reproxy_url");
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
