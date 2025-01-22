<?php
require_once __DIR__ . '/../simplesamlphp/public/_include.php';
require_once __DIR__ . '/functions.php';

/**
 * Logout from the federation
 */
function logout_fed()
{
    $as = new \SimpleSAML\Auth\Simple('default-sp');
    if ($as->isAuthenticated()) {
        $as->logout();
    }
}

?>
