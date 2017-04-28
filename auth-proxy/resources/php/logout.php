<?php

require_once __DIR__ . '/functions.php';
@session_start();

// remove cookies
setcookie(session_name(), '', time() - 1800, '/');
setcookie('jupyter-hub-token', '', time() - 1800, '/');
setcookie('_xsrf', '', time() - 1800, '/');
// destroy session
session_destroy();
// logout federation authentication
logout_fed();
// redirect to login
header('Location: /login');
