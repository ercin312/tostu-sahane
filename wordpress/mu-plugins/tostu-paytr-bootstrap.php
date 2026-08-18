<?php
/**
 * Plugin Name: Tostu PayTR Bootstrap
 * Description: PayTR WooCommerce ödeme yöntemini etkinleştirir (config FTP'de).
 */
if (!defined('ABSPATH')) {
    exit;
}

add_action('init', 'tostu_paytr_bootstrap', 20);

function tostu_paytr_bootstrap()
{
    if (!function_exists('WC')) {
        return;
    }

    $configFile = __DIR__ . '/tostu-paytr-config.php';
    if (!is_readable($configFile)) {
        return;
    }

    $config = include $configFile;
    if (!is_array($config)) {
        return;
    }

    $merchantId = trim((string) ($config['merchant_id'] ?? ''));
    $merchantKey = trim((string) ($config['merchant_key'] ?? ''));
    $merchantSalt = trim((string) ($config['merchant_salt'] ?? ''));
    if ($merchantId === '' || $merchantKey === '' || $merchantSalt === '') {
        return;
    }
    if (str_starts_with($merchantId, 'REPLACE_')) {
        return;
    }

    $plugin = 'paytr-sanal-pos-woocommerce-iframe-api/paytr-sanal-pos-woocommerce-iframe-api.php';
    if (!function_exists('is_plugin_active')) {
        require_once ABSPATH . 'wp-admin/includes/plugin.php';
    }
    if (!is_plugin_active($plugin) && file_exists(WP_PLUGIN_DIR . '/' . $plugin)) {
        activate_plugin($plugin, '', false, true);
    }

    $optionKey = 'woocommerce_paytr_payment_gateway_settings';
    $current = get_option($optionKey, []);
    if (!is_array($current)) {
        $current = [];
    }

    $desired = array_merge(
        [
            'enabled' => 'yes',
            'title' => 'Kredi / Banka Kartı (PayTR)',
            'description' => 'Güvenli ödeme PayTR ile tamamlanır.',
            'logo' => 'yes',
            'paytr_order_status' => 'processing',
            'paytr_ins_difference' => 'no',
            'iframe_theme' => 'no',
            'paytr_log_retention_days' => '7',
            'paytr_log_level' => 'errors',
            'paytr_log_max_file_size_mb' => '5',
            'paytr_error_email_alerts' => 'yes',
            'paytr_error_email_hourly_limit' => '5',
        ],
        $current,
        [
            'enabled' => 'yes',
            'paytr_merchant_id' => $merchantId,
            'paytr_merchant_key' => $merchantKey,
            'paytr_merchant_salt' => $merchantSalt,
            'test' => !empty($config['test_mode']) ? 'yes' : 'no',
        ]
    );

    if ($desired != $current) {
        update_option($optionKey, $desired);
    }
}
