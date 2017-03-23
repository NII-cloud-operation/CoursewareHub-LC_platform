<?php

require_once __DIR__ . '/functions.php';
@session_start();

// セッション用Cookieの破棄
setcookie(session_name(), '', 1);
// セッションファイルの破棄
session_destroy();
// ログアウト完了後に /login.php に遷移
logout_fed();

header('Location: /php/login.php');
