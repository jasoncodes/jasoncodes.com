<?php
header('Content-Type: text/plain');
umask(0022);
passthru('chmod +x _deploy.sh');
passthru('./_deploy.sh 2>&1');
