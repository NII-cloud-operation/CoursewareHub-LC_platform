<?php

require_once __DIR__ . '/../../lib/functions-fed.php';
@session_start();

// remove cookies
setcookie(session_name(), '', time() - 1800, '/');
setcookie('jupyter-hub-token', '', time() - 1800, '/');
setcookie('_xsrf', '', time() - 1800, '/');
// logout federation authentication
logout_fed();

if ($_SESSION['authtype'] == 'lti') {
    if (isset($_SESSION['logout-redirect-url'])) {
        header('Location: ' . $_SESSION['logout-redirect-url']);
    } else {
        $iss = $_SESSION['iss'];
        $vars = array('iss' => $iss);
        template_page('missing_logout_redirect_url.html', $vars);
    }
} else {
    // redirect to login
    header('Location: /login');
}

// destroy session
session_destroy();
