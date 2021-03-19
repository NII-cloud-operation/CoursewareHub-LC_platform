<?php
@session_start();

require_once __DIR__ . '/../../../vendor/autoload.php';
require_once __DIR__ . '/../../../lib/functions.php';
require_once __DIR__ . '/../../../lib/lti/db.php';

use \IMSGlobal\LTI;

try {
    LTI\LTI_OIDC_Login::new(new CoursewareHub_Database())
        ->do_oidc_login_redirect(TOOL_HOST . "/php/lti/service.php")
        ->do_redirect();
} catch (LTI\OIDC_Exception $e) {
    error_log("LTI Login failed: $e");
    error_page(
        "Not Authorized",
        "This tool provider is not available from the link you clicked.");
    http_response_code(403);
}
?>
