import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sylvakru/base/app.dart';
import 'package:sylvakru/base/audio_handler.dart';
import 'package:sylvakru/base/services/color_manager.dart';
import 'package:sylvakru/base/widgets/custom_text_field.dart';
import 'package:sylvakru/l10n/generated/app_localizations.dart';
import 'package:sylvakru/layer/layers_manager.dart';
import 'package:smooth_corner/smooth_corner.dart';

void showCenterMessage(
  BuildContext context,
  String message, {
  int duration = 2000,
}) {
  final overlay = Overlay.of(context);
  final overlayEntry = OverlayEntry(
    builder: (context) => Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 300),
        child: Material(
          color: Colors.black,
          shape: SmoothRectangleBorder(
            smoothness: 1,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              message,
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ),
      ),
    ),
  );

  overlay.insert(overlayEntry);

  Future.delayed(Duration(milliseconds: duration), () {
    overlayEntry.remove();
  });
}

Future<bool> showConfirmDialog(BuildContext context, String action) async {
  final l10n = AppLocalizations.of(context);

  final result = await showAnimationDialog<bool>(
    context: context,
    child: Builder(
      builder: (context) {
        return SizedBox(
          width: 300,
          height: 180,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: ListenableBuilder(
              listenable: Listenable.merge([
                buttonColor.valueNotifier,
                lyricsPageForegroundColor.valueNotifier,
                lyricsPageButtonColor.valueNotifier,
              ]),
              builder: (context, _) {
                return Column(
                  children: [
                    Align(
                      alignment: .centerLeft,
                      child: Text(
                        action,
                        style: TextStyle(
                          fontSize: 25,
                          fontWeight: .bold,
                          color: colorManager.getSpecificTextColor(),
                        ),
                      ),
                    ),
                    SizedBox(height: 15),
                    Align(
                      alignment: .centerLeft,
                      child: Text(
                        l10n.continueMsg,
                        style: TextStyle(
                          fontSize: 14,
                          color: colorManager.getSpecificTextColor(),
                        ),
                      ),
                    ),
                    SizedBox(height: 20),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context, false),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colorManager
                                .getSpecificButtonColor(),
                            foregroundColor: colorManager
                                .getSpecificTextColor(),
                          ),
                          child: Text(l10n.cancel),
                        ),
                        const SizedBox(width: 20),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colorManager
                                .getSpecificButtonColor(),
                            foregroundColor: Colors.red,
                          ),
                          child: Text(l10n.confirm),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    ),
  );
  return result ?? false;
}

Future<String> getInputTextDialog(BuildContext context, String title) async {
  final l10n = AppLocalizations.of(context);

  final controller = TextEditingController();
  final specificTextcolor = colorManager.getSpecificTextColor();

  final result = await showAnimationDialog<String>(
    context: context,
    child: SizedBox(
      width: 300,
      height: isMobile ? 220 : 200,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(30, 20, 30, 20),
        child: Column(
          children: [
            Center(
              child: Text(
                title,
                style: TextStyle(fontSize: 25, color: specificTextcolor),
              ),
            ),
            SizedBox(height: 20),
            CustomTextField(null, controller, compact: false, autoFocus: true),
            SizedBox(height: 30),
            Center(
              child: ListenableBuilder(
                listenable: Listenable.merge([
                  buttonColor.valueNotifier,
                  lyricsPageButtonColor.valueNotifier,
                ]),
                builder: (context, _) {
                  return ElevatedButton(
                    onPressed: () => Navigator.pop(context, controller.text),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorManager.getSpecificButtonColor(),
                      foregroundColor: specificTextcolor,
                    ),
                    child: Text(l10n.confirm),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );

  return result ?? '';
}

Future<T?> showAnimationDialog<T>({
  required BuildContext context,
  bool barrierDismissible = true,
  required Widget child,
}) async {
  Offset offset = Offset.zero;

  final GlobalKey childKey = GlobalKey();
  double childHeight = 0;
  void measureChild() {
    final renderBox = childKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null) {
      final newHeight = renderBox.size.height;
      if (newHeight != childHeight) {
        childHeight = newHeight;
      }
    }
  }

  return await showGeneralDialog<T>(
    context: context,
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (context, animation, _) {
      return StatefulBuilder(
        builder: (context, setState) {
          final mediaQuery = MediaQuery.of(context);
          final screenHeight = mediaQuery.size.height;
          final keyboardHeight = mediaQuery.viewInsets.bottom;
          final isKeyboardOpen = keyboardHeight > 0;
          double getMinOffset() {
            if (childHeight == 0) return double.negativeInfinity;
            return screenHeight / 2 - keyboardHeight - childHeight / 2 - 30;
          }

          WidgetsBinding.instance.addPostFrameCallback((_) {
            measureChild();
            if (!isKeyboardOpen && offset != .zero) {
              setState(() {
                offset = .zero;
              });
            }
          });

          return Stack(
            children: [
              AnimatedBuilder(
                animation: animation,
                builder: (_, _) {
                  return BackdropFilter(
                    filter: ImageFilter.blur(
                      sigmaX: 5 * animation.value,
                      sigmaY: 5 * animation.value,
                    ),
                    child: Container(
                      color: Colors.black.withValues(
                        alpha: 0.3 * animation.value,
                      ),
                    ),
                  );
                },
              ),

              ModalBarrier(
                dismissible: barrierDismissible,
                color: Colors.black.withValues(alpha: 0.3 * animation.value),
                onDismiss: () {
                  Navigator.pop(context);
                },
              ),

              Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  transform: Matrix4.translationValues(0, offset.dy, 0),
                  child: GestureDetector(
                    onVerticalDragUpdate: (details) {
                      if (!isKeyboardOpen) return;

                      setState(() {
                        if (offset.dy < getMinOffset() || offset.dy > 0) {
                          offset += Offset(0, details.delta.dy * 0.15);
                        } else {
                          offset += Offset(0, details.delta.dy);
                        }
                      });
                    },

                    onVerticalDragEnd: (_) {
                      if (!isKeyboardOpen) return;

                      final minOffset = getMinOffset();
                      setState(() {
                        if (offset.dy < minOffset) {
                          offset = Offset(0, minOffset);
                        } else if (offset.dy > 0) {
                          offset = .zero;
                        }
                      });
                    },

                    child: SlideTransition(
                      position:
                          Tween<Offset>(
                            begin: const Offset(0, 1),
                            end: Offset.zero,
                          ).animate(
                            CurvedAnimation(
                              parent: animation,
                              curve: Curves.easeInOutCubic,
                            ),
                          ),
                      child: FadeTransition(
                        opacity: animation,
                        child: ListenableBuilder(
                          listenable: Listenable.merge([
                            layersManager.backgroundChangeNotifier,
                            currentSongNotifier,
                            pageBackgroundColor.valueNotifier,
                            panelColor.valueNotifier,
                          ]),
                          builder: (context, _) {
                            return Material(
                              key: childKey,
                              shape: SmoothRectangleBorder(
                                smoothness: 1,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              color: colorManager.getSpecificBgBaseColor(),
                              clipBehavior: Clip.antiAliasWithSaveLayer,
                              child: Container(
                                color: colorManager.getSpecificBgColor(),
                                child: MediaQuery.removePadding(
                                  context: context,
                                  removeLeft: true,
                                  removeRight: true,
                                  removeTop: true,
                                  removeBottom: true,
                                  child: child,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      );
    },
  );
}

ValueNotifier<bool> vibrationOnNoitifier = ValueNotifier(true);
void tryVibrate() {
  if (vibrationOnNoitifier.value) {
    HapticFeedback.heavyImpact();
  }
}
