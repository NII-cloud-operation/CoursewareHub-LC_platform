<?php
require_once __DIR__ . '/hub-const.php';
require_once __DIR__ . '/const.php';
require_once __DIR__ . '/../simplesamlphp/www/_include.php';

$SESSION_NAME = session_name();


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

/**
 * Check the user autorization of this Coursen
 *
 * @param string $group_list list of groups where a user belongs to
 * @return bool True if user authorized, otherwise False
 */
function check_authorization($group_list)
{
    $result = False;
    if (empty(AUTHOR_GROUP_LIST)) {
        $result = True;
    } else {
       foreach ($group_list as $group) {
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

/**
 * Display template page
 *
 *
 *  @param $template template name
 *  @param $vars template variables
 */
function template_page($template, $vars)
{
    $v = $vars;
    include(__DIR__ . "/../templates/" . $template);
}

/**
 * Display error page
 *
 *  @param $title title string
 *  @param $message message string
 */
function error_page($title, $message)
{
    $v = array('title' => $title, 'message' => $message);
    template_page("error_page.html", $v);
}

/**
 * Get local username form user's mail address
 *
 * @param string $str  mail_address
 * @return string  local username
 */
function get_username_from_mail_address($mail_address)
{
    $result = "";

    // Convert to lower and remove characters except for alphabets and digits
    $wk = explode("@", $mail_address);
    $local_part = strtolower($wk[0]);
    $result = preg_replace('/[^a-zA-Z0-9]/', '', $local_part);
    // Add top 6bytes of hash string
    $hash = substr(md5($mail_address), 0, 6);
    $result .= 'x';
    $result .= $hash;

    return $result;
}


function generate_password($length = 10)
{
    $exclude = "/[1I0O\"\'\(\)\^~\\\`\{\}_\?<>]/";

    while(true) {
        $password = exec("pwgen -1ys $length");
        if (preg_match($exclude, $password)) {
            continue;
        }
        break;
    }
    return $password;
}
