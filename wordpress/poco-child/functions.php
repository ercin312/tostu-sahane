<?php
/**
 * Theme functions and decisions for Poco Child.
 */

if (!defined('ABSPATH')) {
    exit;
}

add_action('wp_enqueue_scripts', 'tostu_poco_child_enqueue_styles', 20);
/**
 * Load child stylesheet after parent theme/plugin styles.
 */
function tostu_poco_child_enqueue_styles() {
    $path = get_stylesheet_directory() . '/style.css';
    $uri  = get_stylesheet_directory_uri() . '/style.css';
    $ver  = file_exists($path) ? (string) filemtime($path) : '2.1.4';

    wp_enqueue_style(
        'poco-child-style',
        $uri,
        array(),
        $ver
    );
}

add_action('wp_enqueue_scripts', 'tostu_force_woocommerce_block_styles', 30);
/**
 * Ensure WooCommerce Blocks base styles load on cart/checkout.
 * Some optimizers / theme setups omit them, which breaks checkbox SVGs.
 */
function tostu_force_woocommerce_block_styles() {
    if (!function_exists('is_checkout') && !function_exists('is_cart')) {
        return;
    }

    $needs_blocks = (function_exists('is_checkout') && is_checkout())
        || (function_exists('is_cart') && is_cart());

    if (!$needs_blocks) {
        return;
    }

    $candidates = array(
        'wc-blocks-style',
        'wc-blocks-style-shared',
        'wc-blocks-packages-style',
        'wc-blocks-checkout-style',
        'wc-blocks-cart-style',
    );

    foreach ($candidates as $handle) {
        if (wp_style_is($handle, 'registered') && !wp_style_is($handle, 'enqueued')) {
            wp_enqueue_style($handle);
        }
    }

    if (!defined('WC_PLUGIN_FILE')) {
        return;
    }

    $fallbacks = array(
        'tostu-wc-blocks-fallback' => 'assets/client/blocks/wc-blocks.css',
        'tostu-wc-checkout-fallback' => 'assets/client/blocks/checkout.css',
    );

    foreach ($fallbacks as $handle => $rel) {
        if (wp_style_is($handle, 'enqueued')) {
            continue;
        }
        $abs = plugin_dir_path(WC_PLUGIN_FILE) . $rel;
        if (file_exists($abs)) {
            wp_enqueue_style(
                $handle,
                plugins_url($rel, WC_PLUGIN_FILE),
                array(),
                defined('WC_VERSION') ? WC_VERSION : null
            );
        }
    }
}
