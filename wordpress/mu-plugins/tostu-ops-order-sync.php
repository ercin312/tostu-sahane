<?php
/**
 * Plugin Name: Tostu Sahane → Ops Sync
 * Description: WooCommerce siparişlerini Tostu Windows/Firestore sipariş sistemine gönderir.
 * Author: Tostu Sahane
 * Version: 1.0.0
 *
 * Bu dosya mu-plugins altında otomatik yüklenir.
 * Secret: aynı klasördeki tostu-ops-config.php (git'e eklenmez).
 */

if (!defined('ABSPATH')) {
    exit;
}

$config_file = __DIR__ . '/tostu-ops-config.php';
if (is_readable($config_file)) {
    require_once $config_file;
}

if (!defined('TOSTU_OPS_WEBHOOK_URL')) {
    define(
        'TOSTU_OPS_WEBHOOK_URL',
        'https://us-central1-tostusahane-e4e71.cloudfunctions.net/woocommerceOrderWebhook'
    );
}

if (!defined('TOSTU_OPS_WEBHOOK_SECRET')) {
    define('TOSTU_OPS_WEBHOOK_SECRET', '');
}

if (!defined('TOSTU_OPS_BRANCH_ID')) {
    define('TOSTU_OPS_BRANCH_ID', 'branch_1');
}

/**
 * @param int $order_id
 */
function tostu_ops_push_order($order_id) {
    if (!function_exists('wc_get_order')) {
        return;
    }

    if (!TOSTU_OPS_WEBHOOK_SECRET) {
        error_log('Tostu Ops sync skipped: TOSTU_OPS_WEBHOOK_SECRET empty');
        return;
    }

    $order_id = absint($order_id);
    if ($order_id <= 0) {
        return;
    }

    $already = get_post_meta($order_id, '_tostu_ops_synced', true);
    if ($already === '1') {
        return;
    }

    $order = wc_get_order($order_id);
    if (!$order) {
        return;
    }

    $status = $order->get_status();
    if (in_array($status, array('cancelled', 'failed', 'refunded', 'checkout-draft'), true)) {
        return;
    }

    $line_items = array();
    foreach ($order->get_items('line_item') as $item_id => $item) {
        $meta = array();
        foreach ($item->get_formatted_meta_data('') as $meta_row) {
            $meta[] = array(
                'key' => wp_strip_all_tags((string) $meta_row->display_key),
                'value' => wp_strip_all_tags((string) $meta_row->display_value),
            );
        }
        $product = $item->get_product();
        $line_items[] = array(
            'id' => $item_id,
            'name' => $item->get_name(),
            'product_id' => $item->get_product_id(),
            'variation_id' => $item->get_variation_id(),
            'quantity' => $item->get_quantity(),
            'subtotal' => $item->get_subtotal(),
            'total' => $item->get_total(),
            'sku' => $product ? $product->get_sku() : '',
            'meta_data' => $meta,
        );
    }

    $payload = array(
        'woo_order_id' => $order_id,
        'branch_id' => TOSTU_OPS_BRANCH_ID,
        'order' => array(
            'id' => $order_id,
            'number' => $order->get_order_number(),
            'status' => $status,
            'total' => $order->get_total(),
            'discount_total' => $order->get_discount_total(),
            'shipping_total' => $order->get_shipping_total(),
            'payment_method' => $order->get_payment_method(),
            'payment_method_title' => $order->get_payment_method_title(),
            'transaction_id' => $order->get_transaction_id(),
            'customer_note' => $order->get_customer_note(),
            'line_items' => $line_items,
            'billing' => array(
                'first_name' => $order->get_billing_first_name(),
                'last_name' => $order->get_billing_last_name(),
                'company' => $order->get_billing_company(),
                'address_1' => $order->get_billing_address_1(),
                'address_2' => $order->get_billing_address_2(),
                'city' => $order->get_billing_city(),
                'state' => $order->get_billing_state(),
                'postcode' => $order->get_billing_postcode(),
                'phone' => $order->get_billing_phone(),
                'email' => $order->get_billing_email(),
            ),
            'shipping' => array(
                'first_name' => $order->get_shipping_first_name(),
                'last_name' => $order->get_shipping_last_name(),
                'company' => $order->get_shipping_company(),
                'address_1' => $order->get_shipping_address_1(),
                'address_2' => $order->get_shipping_address_2(),
                'city' => $order->get_shipping_city(),
                'state' => $order->get_shipping_state(),
                'postcode' => $order->get_shipping_postcode(),
            ),
        ),
    );

    $response = wp_remote_post(
        TOSTU_OPS_WEBHOOK_URL,
        array(
            'timeout' => 20,
            'headers' => array(
                'Content-Type' => 'application/json',
                'X-Tostu-Webhook-Secret' => TOSTU_OPS_WEBHOOK_SECRET,
            ),
            'body' => wp_json_encode($payload),
        )
    );

    if (is_wp_error($response)) {
        error_log('Tostu Ops sync failed: ' . $response->get_error_message());
        update_post_meta($order_id, '_tostu_ops_sync_error', $response->get_error_message());
        return;
    }

    $code = (int) wp_remote_retrieve_response_code($response);
    $body = wp_remote_retrieve_body($response);
    if ($code >= 200 && $code < 300) {
        update_post_meta($order_id, '_tostu_ops_synced', '1');
        update_post_meta($order_id, '_tostu_ops_synced_at', gmdate('c'));
        delete_post_meta($order_id, '_tostu_ops_sync_error');
        return;
    }

    error_log('Tostu Ops sync HTTP ' . $code . ': ' . $body);
    update_post_meta($order_id, '_tostu_ops_sync_error', 'HTTP ' . $code . ' ' . $body);
}

add_action('woocommerce_checkout_order_processed', function ($order_id) {
    tostu_ops_push_order($order_id);
}, 20, 1);

add_action('woocommerce_payment_complete', function ($order_id) {
    tostu_ops_push_order($order_id);
}, 20, 1);

add_action('woocommerce_order_status_processing', function ($order_id) {
    tostu_ops_push_order($order_id);
}, 20, 1);

add_action('woocommerce_order_status_completed', function ($order_id) {
    tostu_ops_push_order($order_id);
}, 20, 1);
