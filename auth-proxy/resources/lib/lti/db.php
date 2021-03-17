<?php
@session_start();
require_once __DIR__ . '/../../vendor/autoload.php';

define("TOOL_HOST", (
    isset($_SERVER['HTTP_X_FORWARDED_PROTO']) ?
        $_SERVER['HTTP_X_FORWARDED_PROTO'] :
        $_SERVER['REQUEST_SCHEME']) . '://' . $_SERVER['HTTP_HOST']);
use \IMSGlobal\LTI;

class CoursewareHub_Database implements LTI\Database {
    private $registrations;

    public function __construct() {
        $regs = [];
        $reg_configs = array_diff(scandir(__DIR__ . '/configs'), array('..', '.', '.DS_Store', '.gitignore'));
        foreach ($reg_configs as $key => $reg_config) {
            $regs = array_merge($regs, json_decode(file_get_contents(__DIR__ . "/configs/$reg_config"), true));
        }
        $this->registrations = $regs;
    }

    public function find_registration_by_issuer($iss) {
        $regs = $this->registrations;
        if (empty($regs[$iss])) {
            return false;
        }
        return LTI\LTI_Registration::new()
            ->set_auth_login_url($regs[$iss]['auth_login_url'])
            ->set_auth_token_url($regs[$iss]['auth_token_url'])
            ->set_client_id($regs[$iss]['client_id'])
            ->set_key_set_url($regs[$iss]['key_set_url'])
            ->set_issuer($iss)
            ->set_tool_private_key($this->private_key($iss));
    }

    public function find_deployment($iss, $deployment_id) {
        $regs = $this->registrations;
        if (!in_array($deployment_id, $regs[$iss]['deployment'])) {
            return false;
        }
        return LTI\LTI_Deployment::new()
            ->set_deployment_id($deployment_id);
    }

    private function private_key($iss) {
        $regs = $this->registrations;
        return file_get_contents(__DIR__ . $regs[$iss]['private_key_file']);
    }
}
?>
