<?php
/**
 * Yerel/FTP kopya — GIT'E EKLENMEZ.
 * Kopyala: tostu-paytr-config.example.php → tostu-paytr-config.php
 *
 * PayTR WooCommerce gateway'ini açar ve API bilgilerini yazar.
 */
if (!defined('ABSPATH')) {
    exit;
}

/** @var array{merchant_id:string,merchant_key:string,merchant_salt:string,test_mode?:bool} */
return [
    'merchant_id' => 'REPLACE_MERCHANT_ID',
    'merchant_key' => 'REPLACE_MERCHANT_KEY',
    'merchant_salt' => 'REPLACE_MERCHANT_SALT',
    'test_mode' => false,
];
