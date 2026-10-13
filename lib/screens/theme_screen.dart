import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../services/settings_service.dart';

/// 主题页面：预设配色 + 动态取色（跟随系统壁纸）
class ThemeScreen extends StatelessWidget {
  const ThemeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('主题')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('预设配色',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(color: cs.primary)),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.15,
            ),
            itemCount: SettingsService.themePresets.length,
            itemBuilder: (context, i) {
              final p = SettingsService.themePresets[i];
              final selected = settings.themeSeed == p.value &&
                  !settings.dynamicColor;
              return GestureDetector(
                onTap: () =>
                    context.read<SettingsService>().setThemeSeed(p.value),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Color(p.value),
                        shape: BoxShape.circle,
                        border: selected
                            ? Border.all(
                                color: Colors.white, width: 3)
                            : null,
                        boxShadow: [
                          BoxShadow(
                            color: Color(p.value).withValues(alpha: 0.4),
                            blurRadius: selected ? 12 : 6,
                          ),
                        ],
                      ),
                      child: selected
                          ? const Icon(Icons.check,
                              color: Colors.white, size: 28)
                          : null,
                    ),
                    const SizedBox(height: 6),
                    Text(p.name,
                        style: TextStyle(
                          fontSize: 12,
                          color: selected
                              ? Colors.white
                              : AppColors.textSecondary,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.normal,
                        )),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          const Divider(height: 32),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('动态取色'),
            subtitle: const Text('跟随系统壁纸生成主题色（Android 12+）',
                style: TextStyle(
                    fontSize: 12, color: AppColors.textSecondary)),
            value: settings.dynamicColor,
            onChanged: (v) =>
                context.read<SettingsService>().setDynamicColor(v),
          ),
          if (settings.dynamicColor &&
              settings.systemScheme == null)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text('当前系统不支持动态取色，将使用默认配色',
                  style: TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
            ),
        ],
      ),
    );
  }
}
