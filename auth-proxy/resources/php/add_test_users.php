<?php

require_once __DIR__ . '/db.php';


$user_info = array(
array('mail_addr' => 'k-oyakata@axsh.net', 'password' => 'j7w118shi'),
array('mail_addr' => 'interceptershinden@gmail.com', 'password' => 'j7w118sh')
);
add_local_users($user_info);
?>
