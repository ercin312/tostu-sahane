import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/locale_keys.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/branch_hours_utils.dart';
import '../../../../core/utils/format_utils.dart';
import '../../../../core/utils/localized_text.dart';
import '../../../../shared/data/models/api_models.dart';
import '../../../../shared/domain/entities/branch.dart';
import '../../../../shared/domain/entities/product.dart';
import '../providers/admin_provider.dart';

Future<bool?> showAdminDeleteConfirm(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(LocaleKeys.adminDeleteConfirm.tr()),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(LocaleKeys.commonCancel.tr()),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(
            LocaleKeys.commonRemove.tr(),
            style: const TextStyle(color: AppColors.error),
          ),
        ),
      ],
    ),
  );
}

Future<void> showBranchFormDialog(
  BuildContext context,
  WidgetRef ref, {
  Branch? branch,
}) async {
  final nameController = TextEditingController(text: branch?.name ?? '');
  final addressController = TextEditingController(text: branch?.address ?? '');
  final latController = TextEditingController(
    text: branch?.latitude.toString() ?? '41.0',
  );
  final lngController = TextEditingController(
    text: branch?.longitude.toString() ?? '29.0',
  );
  final openTimeController = TextEditingController(
    text: branch?.openTime ?? '09:00',
  );
  final closeTimeController = TextEditingController(
    text: branch?.closeTime ?? '23:00',
  );

  bool isValidTime(String value) =>
      RegExp(r'^\d{2}:\d{2}$').hasMatch(value.trim());
  await showDialog<void>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(
          branch == null
              ? LocaleKeys.adminAddBranch.tr()
              : LocaleKeys.adminEditBranch.tr(),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: LocaleKeys.adminBranchName.tr(),
                ),
              ),
              TextField(
                controller: addressController,
                decoration: InputDecoration(
                  labelText: LocaleKeys.adminBranchAddress.tr(),
                ),
              ),
              TextField(
                controller: latController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: LocaleKeys.adminBranchLat.tr(),
                ),
              ),
              TextField(
                controller: lngController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: LocaleKeys.adminBranchLng.tr(),
                ),
              ),
              TextField(
                controller: openTimeController,
                decoration: InputDecoration(
                  labelText: LocaleKeys.adminBranchOpenTime.tr(),
                ),
              ),
              TextField(
                controller: closeTimeController,
                decoration: InputDecoration(
                  labelText: LocaleKeys.adminBranchCloseTime.tr(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(LocaleKeys.commonCancel.tr()),
          ),
          TextButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final address = addressController.text.trim();
              final lat = double.tryParse(latController.text.trim());
              final lng = double.tryParse(lngController.text.trim());
              final openTime = openTimeController.text.trim();
              final closeTime = closeTimeController.text.trim();
              if (name.isEmpty ||
                  address.isEmpty ||
                  lat == null ||
                  lng == null ||
                  !isValidTime(openTime) ||
                  !isValidTime(closeTime)) {
                return;
              }
              if (branch == null) {
                await ref.read(adminBranchesProvider.notifier).createBranch(
                      name: name,
                      address: address,
                      latitude: lat,
                      longitude: lng,
                      openTime: openTime,
                      closeTime: closeTime,
                    );
              } else {
                await ref.read(adminBranchesProvider.notifier).updateBranch(
                      branch.copyWith(
                        name: name,
                        address: address,
                        latitude: lat,
                        longitude: lng,
                        openTime: openTime,
                        closeTime: closeTime,
                      ),
                    );
              }
              if (context.mounted) Navigator.pop(context);
            },
            child: Text(LocaleKeys.commonSave.tr()),
          ),
        ],
      );
    },
  );

  nameController.dispose();
  addressController.dispose();
  latController.dispose();
  lngController.dispose();
  openTimeController.dispose();
  closeTimeController.dispose();
}

Future<void> showProductFormDialog(
  BuildContext context,
  WidgetRef ref, {
  Product? product,
}) async {
  final nameController =
      TextEditingController(text: product != null ? localizedOrRaw(product.nameKey) : '');
  final descController = TextEditingController(
    text: product != null ? localizedOrRaw(product.descriptionKey) : '',
  );
  final priceController = TextEditingController(
    text: product?.price.toString() ?? '',
  );
  var category = product?.category ?? ProductCategory.tost;

  await showDialog<void>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(
              product == null
                  ? LocaleKeys.adminAddProduct.tr()
                  : LocaleKeys.adminEditProduct.tr(),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: LocaleKeys.adminProductName.tr(),
                    ),
                  ),
                  TextField(
                    controller: descController,
                    decoration: InputDecoration(
                      labelText: LocaleKeys.adminProductDescription.tr(),
                    ),
                  ),
                  TextField(
                    controller: priceController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: LocaleKeys.adminProductPrice.tr(),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  DropdownButtonFormField<ProductCategory>(
                    value: category,
                    decoration: InputDecoration(
                      labelText: LocaleKeys.adminProductCategory.tr(),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: ProductCategory.tost,
                        child: Text(LocaleKeys.customerCategoryTost.tr()),
                      ),
                      DropdownMenuItem(
                        value: ProductCategory.sahanda,
                        child: Text(LocaleKeys.customerCategorySahanda.tr()),
                      ),
                      DropdownMenuItem(
                        value: ProductCategory.drink,
                        child: Text(LocaleKeys.customerCategoryDrink.tr()),
                      ),
                      DropdownMenuItem(
                        value: ProductCategory.snack,
                        child: Text(LocaleKeys.customerCategorySnack.tr()),
                      ),
                    ],
                    onChanged: (v) => setState(() => category = v!),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(LocaleKeys.commonCancel.tr()),
              ),
              TextButton(
                onPressed: () async {
                  final name = nameController.text.trim();
                  final desc = descController.text.trim();
                  final price = double.tryParse(priceController.text.trim());
                  if (name.isEmpty || price == null) return;

                  if (product == null) {
                    await ref.read(adminProductsProvider.notifier).createProduct(
                          name: name,
                          description: desc,
                          price: price,
                          category: category,
                        );
                  } else {
                    await ref.read(adminProductsProvider.notifier).updateProduct(
                          product.copyWith(
                            nameKey: name,
                            descriptionKey: desc,
                            price: price,
                            category: category,
                          ),
                        );
                  }
                  if (context.mounted) Navigator.pop(context);
                },
                child: Text(LocaleKeys.commonSave.tr()),
              ),
            ],
          );
        },
      );
    },
  );

  nameController.dispose();
  descController.dispose();
  priceController.dispose();
}

Future<void> showUserFormDialog(
  BuildContext context,
  WidgetRef ref, {
  AdminUserModel? user,
}) async {
  final nameController = TextEditingController(
    text: user != null ? localizedOrRaw(user.name) : '',
  );
  final phoneController = TextEditingController(text: user?.phone ?? '');
  final usernameController =
      TextEditingController(text: user?.username ?? '');
  final passwordController = TextEditingController(text: user?.password ?? '');
  var role = user?.role ?? 'branchManager';
  var branchId = user?.branchId;
  final branches = ref.read(adminBranchesProvider).value ?? [];

  await showDialog<void>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          final needsBranch = role == 'branchManager' ||
              role == 'branchStaff' ||
              role == 'courier' ||
              role == 'waiter' ||
              role == 'kitchenStaff';
          final usesUsernameLogin =
              role == 'waiter' || role == 'kitchenStaff';
          return AlertDialog(
            title: Text(
              user == null
                  ? LocaleKeys.adminAddUser.tr()
                  : LocaleKeys.adminEditUser.tr(),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: LocaleKeys.adminUserName.tr(),
                    ),
                  ),
                  TextField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: LocaleKeys.adminUserPhone.tr(),
                    ),
                  ),
                  if (usesUsernameLogin) ...[
                    const SizedBox(height: AppSpacing.sm),
                    TextField(
                      controller: usernameController,
                      decoration: InputDecoration(
                        labelText: LocaleKeys.adminUserUsername.tr(),
                        hintText: LocaleKeys.adminUserUsernameHint.tr(),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextField(
                      controller: passwordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: LocaleKeys.adminUserPassword.tr(),
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.sm),
                  DropdownButtonFormField<String>(
                    value: role,
                    decoration: InputDecoration(
                      labelText: LocaleKeys.adminUserRole.tr(),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 'branchManager',
                        child: Text(LocaleKeys.authRoleBranch.tr()),
                      ),
                      DropdownMenuItem(
                        value: 'branchStaff',
                        child: Text(LocaleKeys.authRoleBranchStaff.tr()),
                      ),
                      DropdownMenuItem(
                        value: 'waiter',
                        child: Text(LocaleKeys.authRoleWaiter.tr()),
                      ),
                      DropdownMenuItem(
                        value: 'kitchenStaff',
                        child: Text(LocaleKeys.authRoleKitchenStaff.tr()),
                      ),
                      DropdownMenuItem(
                        value: 'courier',
                        child: Text(LocaleKeys.authRoleCourier.tr()),
                      ),
                      DropdownMenuItem(
                        value: 'customer',
                        child: Text(LocaleKeys.authRoleCustomer.tr()),
                      ),
                    ],
                    onChanged: (v) => setState(() => role = v!),
                  ),
                  if (needsBranch && branches.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    DropdownButtonFormField<String>(
                      value: branchId ?? branches.first.id,
                      decoration: InputDecoration(
                        labelText: LocaleKeys.adminUserBranch.tr(),
                      ),
                      items: branches
                          .map(
                            (b) => DropdownMenuItem(
                              value: b.id,
                              child: Text(b.name),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => branchId = v),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(LocaleKeys.commonCancel.tr()),
              ),
              TextButton(
                onPressed: () async {
                  final name = nameController.text.trim();
                  final phone = phoneController.text.trim();
                  final username = usernameController.text.trim().toLowerCase();
                  final password = passwordController.text;
                  if (name.isEmpty) return;
                  if (!usesUsernameLogin && phone.isEmpty) return;
                  if (usesUsernameLogin &&
                      (username.isEmpty || password.length < 6)) {
                    return;
                  }
                  final resolvedBranchId = needsBranch
                      ? (branchId ??
                          (branches.isNotEmpty ? branches.first.id : null))
                      : null;

                  if (user == null) {
                    await ref.read(adminUsersProvider.notifier).createUser(
                          name: name,
                          phone: phone,
                          role: role,
                          branchId: resolvedBranchId,
                          username: usesUsernameLogin ? username : null,
                          password: usesUsernameLogin ? password : null,
                        );
                  } else {
                    await ref.read(adminUsersProvider.notifier).updateUser(
                          user.copyWith(
                            name: name,
                            phone: phone,
                            role: role,
                            branchId: resolvedBranchId,
                            username:
                                usesUsernameLogin ? username : user.username,
                            password: password.isNotEmpty
                                ? password
                                : user.password,
                          ),
                        );
                  }
                  if (context.mounted) Navigator.pop(context);
                },
                child: Text(LocaleKeys.commonSave.tr()),
              ),
            ],
          );
        },
      );
    },
  );

  nameController.dispose();
  phoneController.dispose();
  usernameController.dispose();
  passwordController.dispose();
}

String adminRoleLabel(String role) {
  return switch (role) {
    'branchManager' => LocaleKeys.authRoleBranch.tr(),
    'branchStaff' => LocaleKeys.authRoleBranchStaff.tr(),
    'waiter' => LocaleKeys.authRoleWaiter.tr(),
    'kitchenStaff' => LocaleKeys.authRoleKitchenStaff.tr(),
    'courier' => LocaleKeys.authRoleCourier.tr(),
    'customer' => LocaleKeys.authRoleCustomer.tr(),
    'superAdmin' => LocaleKeys.authRoleAdmin.tr(),
    _ => role,
  };
}

String adminCategoryLabel(ProductCategory category) {
  return switch (category) {
    ProductCategory.tost => LocaleKeys.customerCategoryTost.tr(),
    ProductCategory.sahanda => LocaleKeys.customerCategorySahanda.tr(),
    ProductCategory.drink => LocaleKeys.customerCategoryDrink.tr(),
    ProductCategory.snack => LocaleKeys.customerCategorySnack.tr(),
    ProductCategory.combo => LocaleKeys.customerCategoryCombo.tr(),
    ProductCategory.all => LocaleKeys.customerCategoriesAll.tr(),
  };
}

String formatProductPrice(double price) => FormatUtils.currency(price);
