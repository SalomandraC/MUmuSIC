// import 'package:flutter/material.dart';
// import 'package:go_router/go_router.dart';
// import 'package:RandomTierList/app/app_routes.dart';

// /// Примеры использования навигации с go_router
// /// 
// /// Этот файл можно удалить после изучения примеров
// class NavigationExamples {
//   /// Пример 1: Простая навигация по пути
//   static void navigateToHome(BuildContext context) {
//     context.go(AppRoutes.home);
//   }

//   /// Пример 2: Навигация по имени маршрута
//   static void navigateToSettingsByName(BuildContext context) {
//     context.goNamed(AppRoutes.settingsName);
//   }

//   /// Пример 3: Push (добавить в стек) вместо замены
//   static void pushToSettings(BuildContext context) {
//     context.push(AppRoutes.settings);
//   }

//   /// Пример 4: Push с именем маршрута
//   static void pushToSettingsByName(BuildContext context) {
//     context.pushNamed(AppRoutes.settingsName);
//   }

//   /// Пример 5: Навигация с параметрами
//   /// Для этого нужно добавить параметры в GoRoute:
//   /// ```dart
//   /// GoRoute(
//   ///   path: '/user/:id',
//   ///   builder: (context, state) {
//   ///     final id = state.pathParameters['id']!;
//   ///     return UserScreen(userId: id);
//   ///   },
//   /// )
//   /// ```
//   /// Затем использовать:
//   /// ```dart
//   /// context.go('/user/123');
//   /// ```

//   /// Пример 6: Навигация с query параметрами
//   /// ```dart
//   /// context.go('/settings?tab=theme');
//   /// ```
//   /// Получить параметр:
//   /// ```dart
//   /// final tab = state.uri.queryParameters['tab'];
//   /// ```

//   /// Пример 7: Возврат назад
//   static void goBack(BuildContext context) {
//     if (context.canPop()) {
//       context.pop();
//     }
//   }

//   /// Пример 8: Возврат с результатом
//   static void goBackWithResult(BuildContext context, String result) {
//     context.pop(result);
//   }

//   /// Пример 9: Замена текущего маршрута
//   static void replaceWithHome(BuildContext context) {
//     context.goReplacement(AppRoutes.home);
//   }
// }

// /// Пример виджета с кнопками навигации
// class NavigationExampleWidget extends StatelessWidget {
//   const NavigationExampleWidget({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return Column(
//       mainAxisAlignment: MainAxisAlignment.center,
//       children: [
//         ElevatedButton(
//           onPressed: () => NavigationExamples.navigateToHome(context),
//           child: const Text('Перейти на главную (go)'),
//         ),
//         const SizedBox(height: 8),
//         ElevatedButton(
//           onPressed: () => NavigationExamples.pushToSettings(context),
//           child: const Text('Открыть настройки (push)'),
//         ),
//         const SizedBox(height: 8),
//         ElevatedButton(
//           onPressed: () => NavigationExamples.goBack(context),
//           child: const Text('Назад'),
//         ),
//       ],
//     );
//   }
// }

