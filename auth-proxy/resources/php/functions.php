<?php
require_once __DIR__ . '/hub-const.php';
require_once __DIR__ . '/const.php';
require_once __DIR__ . '/../simplesamlphp/www/_include.php';

$SESSION_NAME = session_name();

/*
function session_start()
{
    session_set_cookie_params($lifetime);
    @session_start();
}
*/

/**
 * Redirect to the JupyterHub if local user was authenticated.
 */
function redirect_by_local_user_session()
{
    @session_start();

    if (isset($_SESSION['username'])) {
        // check user entry

        // redirect to hub
        header("X-Accel-Redirect: /entrance/");
        header("X-Reproxy-URL: ".HUB_URL.$_SERVER['HTTP_X_REPROXY_URI']);
        exit;
    }
}

/**
 * Redirect to the JupyterHub if Gakunin user was authenticated.
 */
function redirect_by_fed_user_session()
{
    @session_start();

    $as = new SimpleSAML_Auth_Simple('default-sp');
    if ($as->isAuthenticated()) {
        if (isset($_SESSION['username'])) {
            // redirect to JupyterHub
            header("X-Accel-Redirect: /entrance/");
            header("X-Reproxy-URL: ".HUB_URL.$_SERVER['HTTP_X_REPROXY_URI']);
        } else { 
            // maybe access to other course
            // redirect to authenticator of JupyterHub
            $attributes = $as->getAttributes();
            $mail_address = $attributes[GF_ATTRIBUTES['mail']][0];
            $group_list = $attributes[GF_ATTRIBUTES['isMemberOf']];
            // check authorization
            if (check_authorization($group_list)) {
                session_regenerate_id(true);
                $username = get_username_from_mail_address($mail_address);
                $_SESSION['username'] = $username;

                header("X-Accel-Redirect: /entrance/");
                header("X-Reproxy-URL: ".HUB_URL.'/'.COURSE_NAME."/hub/login");
                header("X-REMOTE-USER: $username");
            } else {
                // redirect to message page
                header("X-Accel-Redirect: /entrance/");
                header("X-Reproxy-URL: https://".$_SERVER['HTTP_HOST']."/no_author");
            } 
        }
        exit;
    }
}

/**
 * Logout from the federation
 */
function logout_fed()
{
    $as = new SimpleSAML_Auth_Simple('default-sp');
    if ($as->isAuthenticated()) {
        $as->logout();
    }
}

/**
 * Check the user autorization of this Coursen
 *
 * @param string $group_list list of groups where a user belongs to
 * @return bool True if user authorized, otherwise False
 */
function check_authorization($group_list)
{
    $result = True;
    if (empty(AUTHOR_GROUP_LIST)) {
        $result = True;
    } else {
       foreach ($group_lista as $group) {
           if (in_array($group, AUTHOR_GROUP_LIST)) { 
               $result = True;
               break;
           }
       }   
    }

    return $result;
}

/**
 * Generate CSRF token based on th session id.
 *
 * @return string  generated token
 */
function generate_token()
{
    return hash('sha256', session_id());
}

/**
 * Validate CSRF token
 *
 * @param string $token  CSRF token
 * @return bool  result of validation
 */
function validate_token($token)
{
    return $token === generate_token();
}

/**
 * Wraper function of the 'htmlspecialchars'
 *
 * @param string $str  source string
 * @return string  entity string
 */
function h($str)
{
    return htmlspecialchars($str, ENT_QUOTES, 'UTF-8');
}

function get_username_from_mail_address($mail_address)
{
    $result = "";

    // Convert to lower and remove characters except alphabetic
    $wk = explode("@", $mail_address);
    $local_part = strtolower($wk[0]);
    $result = preg_replace('/[^a-zA-Z]/', '', $local_part);    
    // Add top 6bytes of hash string
    $hash = substr(md5($mail_address), 0, 6);
    $result .= $hash;

    return $result;
}
