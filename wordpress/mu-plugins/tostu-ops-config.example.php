<?php
/**
 * Yerel/FTP kopya — GIT'E EKLENMEZ.
 * Kopyala: tostu-ops-config.example.php → tostu-ops-config.php
 */
if (!defined('ABSPATH')) {
    exit;
}

define(
    'TOSTU_OPS_WEBHOOK_URL',
    'https://us-central1-tostusahane-e4e71.cloudfunctions.net/woocommerceOrderWebhook'
);
define('TOSTU_OPS_WEBHOOK_SECRET', 'REPLACE_WITH_WOOCOMMERCE_WEBHOOK_SECRET');
define('TOSTU_OPS_BRANCH_ID', 'branch_1');
