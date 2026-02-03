/// ProMould Design System - Confirm Dialog Component
/// Standardized confirmation dialogs

import 'package:flutter/material.dart';
import '../theme/theme.dart';

enum DialogType { info, warning, danger, success }

class ConfirmDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final DialogType type;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;
  final Widget? content;

  const ConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmLabel = 'Confirm',
    this.cancelLabel = 'Cancel',
    this.type = DialogType.info,
    this.onConfirm,
    this.onCancel,
    this.content,
  });

  /// Show a confirmation dialog and return the result
  static Future<bool> show({
    required BuildContext context,
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
    String cancelLabel = 'Cancel',
    DialogType type = DialogType.info,
    Widget? content,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => ConfirmDialog(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        type: type,
        content: content,
      ),
    );
    return result ?? false;
  }

  /// Show a danger confirmation dialog
  static Future<bool> showDanger({
    required BuildContext context,
    required String title,
    required String message,
    String confirmLabel = 'Delete',
  }) {
    return show(
      context: context,
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      type: DialogType.danger,
    );
  }

  Color get _typeColor {
    switch (type) {
      case DialogType.info:
        return AppColors.info;
      case DialogType.warning:
        return AppColors.warning;
      case DialogType.danger:
        return AppColors.error;
      case DialogType.success:
        return AppColors.success;
    }
  }

  IconData get _typeIcon {
    switch (type) {
      case DialogType.info:
        return Icons.info_outline;
      case DialogType.warning:
        return Icons.warning_amber;
      case DialogType.danger:
        return Icons.error_outline;
      case DialogType.success:
        return Icons.check_circle_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surfaceElevated,
      shape: RoundedRectangleBorder(
        borderRadius: AppSpacing.cardRadius,
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: _typeColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child: Icon(_typeIcon, color: _typeColor, size: 24),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              title,
              style: AppTypography.headlineSmall,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          if (content != null) ...[
            const SizedBox(height: AppSpacing.lg),
            content!,
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            onCancel?.call();
            Navigator.of(context).pop(false);
          },
          child: Text(cancelLabel),
        ),
        ElevatedButton(
          onPressed: () {
            onConfirm?.call();
            Navigator.of(context).pop(true);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: type == DialogType.danger ? AppColors.error : null,
          ),
          child: Text(confirmLabel),
        ),
      ],
    );
  }
}

/// Input dialog for getting user input
class InputDialog extends StatefulWidget {
  final String title;
  final String? message;
  final String? initialValue;
  final String? hintText;
  final String confirmLabel;
  final String cancelLabel;
  final int maxLines;
  final String? Function(String?)? validator;

  const InputDialog({
    super.key,
    required this.title,
    this.message,
    this.initialValue,
    this.hintText,
    this.confirmLabel = 'Submit',
    this.cancelLabel = 'Cancel',
    this.maxLines = 1,
    this.validator,
  });

  static Future<String?> show({
    required BuildContext context,
    required String title,
    String? message,
    String? initialValue,
    String? hintText,
    String confirmLabel = 'Submit',
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return showDialog<String>(
      context: context,
      builder: (ctx) => InputDialog(
        title: title,
        message: message,
        initialValue: initialValue,
        hintText: hintText,
        confirmLabel: confirmLabel,
        maxLines: maxLines,
        validator: validator,
      ),
    );
  }

  @override
  State<InputDialog> createState() => _InputDialogState();
}

class _InputDialogState extends State<InputDialog> {
  late TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (widget.validator != null) {
      final error = widget.validator!(_controller.text);
      if (error != null) {
        setState(() => _error = error);
        return;
      }
    }
    Navigator.of(context).pop(_controller.text);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surfaceElevated,
      shape: RoundedRectangleBorder(
        borderRadius: AppSpacing.cardRadius,
      ),
      title: Text(widget.title, style: AppTypography.headlineSmall),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.message != null) ...[
            Text(
              widget.message!,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          TextField(
            controller: _controller,
            maxLines: widget.maxLines,
            decoration: InputDecoration(
              hintText: widget.hintText,
              errorText: _error,
            ),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(widget.cancelLabel),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
