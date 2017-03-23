<?php
require_once __DIR__ . '/hub-const.php';
require_once __DIR__ . '/functions.php';

// DSN for Database 
const DSN = 'pgsql:dbname='. DB_NAME. ' host=' . DB_HOST. ' port=' . DB_PORT;

/**
 * Add local user.
 *
 * @param string $mail_addr  mail address of user to be added. 
 * @param string $password  password of user to be added. 
 */
function add_local_user($mail_addr, $password)
{
    $user_info[0] = array(array('mail_addr' => $mail_addr, 'password' => $password));
    try {
        add_local_users($user_info);
    } catch (Exception $e) {
        throw $e;
    }
}


/**
 * Add local users.
 *
 * @param string $user_info  array of user's mail address and password to be added. 
 */
function add_local_users($user_info)
{
    $insert = "INSERT INTO local_users VALUES(nextval('local_users_id_seq'), :user_name, :password, :mail);";
    try {
        $dbh = new PDO(DSN, DB_USER, DB_PASS, array(PDO::ATTR_ERRMODE=>PDO::ERRMODE_EXCEPTION));
    } catch (Exception $e) {
        $dbh = null;
        throw $e;
    } 

    try {
        $dbh->beginTransaction(); 
        foreach ($user_info as $info) {
            $user_name = get_username_from_mail_address($info['mail_addr']);
            $hashed_password = password_hash($info['password'], CRYPT_BLOWFISH); 
            $st = $dbh->prepare($insert);
            $rep = $st->execute(array(':user_name'=>$user_name, ':password'=>$hashed_password, ':mail'=>$info['mail_addr']));
        }
        $rep = $dbh->commit(); 
        $st = null;
        $dbh = null;
    } catch (Exception $e) {
        $st = null;
        $dbh = null;
        throw $e;
    } 
}


/**
 * Delete local users.
 *
 * @param string $mail_addrs array of user's mail address to be deleted. 
 */
function delete_local_users($mail_addrs)
{
    $delete = "DELETE FROM local_users where mail = :mail_addr;";
    try {
        $dbh = new PDO(DSN, DB_USER, DB_PASS, array(PDO::ATTR_ERRMODE=>PDO::ERRMODE_EXCEPTION));
    } catch (Exception $e) {
        $dbh = null;
        throw $e;
    } 
    $st = null;
    try {
        $dbh->beginTransaction(); 
        foreach ($mail as $mail_addrs) {
            $st = $dbh->prepare($delete);
            $st->execute(array(':mail_addr' => $mail));
        }
        $dbh->commit(); 
        $st = null;
        $dbh = null;
    } catch (Exception $e) {
        $st = null;
        $dbh = null;
        throw $e;
    } 
}


/**
 * Authenticated local users.
 *
 * @param string $mail_addr  mail address of user. 
 * @param string $password  password of user. 
 * @return boolean return True if user was authenticated, owtherwise return False.
 */
function authenticate_local_user($mail_addr, $password)
{
    $result = False;

    if (!empty($mail_addr) && !empty($password)) {
        $query = "SELECT * FROM local_users where mail = :mail_addr;";
        try {
            $dbh = new PDO(DSN, DB_USER, DB_PASS, array(PDO::ATTR_ERRMODE=>PDO::ERRMODE_EXCEPTION));
        } catch (Exception $e) {
            $dbh = null;
            throw $e;
        } 
        $st = $dbh->prepare($query);
        $st->execute(array(':mail_addr' => $mail_addr));
        if ($row = $st->fetch(PDO::FETCH_ASSOC)) {
            if (password_verify($password, $row['password'])) {
                $result = True;
            }
        }
        $st = null;
        $dbh = null;
    }

    return $result;
}

?>
