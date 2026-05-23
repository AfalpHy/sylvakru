import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sylvakru/base/services/color_manager.dart';
import 'package:sylvakru/base/app.dart';
import 'package:sylvakru/base/services/keyboard.dart';

class CustomTextField extends StatefulWidget {
  final String? name;
  final TextEditingController controller;
  final bool expand;
  final bool onlyNumber;
  final bool compact;
  final bool autoFocus;

  const CustomTextField(
    this.name,
    this.controller, {
    super.key,
    this.expand = false,
    this.onlyNumber = false,
    this.compact = true,
    this.autoFocus = false,
  });

  @override
  State<StatefulWidget> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField> {
  FocusNode inkwellNode = FocusNode();
  FocusNode textFieldNode = FocusNode();
  final canRequestNotifier = ValueNotifier(false);

  @override
  void initState() {
    super.initState();
    canRequestNotifier.value = widget.autoFocus;
    textFieldNode.addListener(() {
      isTyping = textFieldNode.hasFocus;
      if (!textFieldNode.hasFocus) {
        inkwellNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    inkwellNode.dispose();
    textFieldNode.dispose();
    canRequestNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (widget.name != null)
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '${widget.name}:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),

        Focus(
          canRequestFocus: false,
          onKeyEvent: (node, event) {
            if (!isTV) {
              return .ignored;
            }
            if (event is KeyDownEvent) {
              if (event.logicalKey == .select || event.logicalKey == .enter) {
                canRequestNotifier.value = true;
                textFieldNode.unfocus();
                Future.delayed((Duration(milliseconds: 100)), () {
                  textFieldNode.requestFocus();
                });
                return .handled;
              }
            }
            return .ignored;
          },
          child: InkWell(
            focusNode: inkwellNode,
            // ensure inkwell can focus
            onTap: isTV ? () {} : null,
            child: AnimatedBuilder(
              animation: inkwellNode,
              builder: (context, child) {
                return PopScope(
                  canPop: !inkwellNode.hasFocus,
                  onPopInvokedWithResult: (didPop, result) {
                    if (didPop || !inkwellNode.hasFocus) return;

                    if (textFieldNode.hasFocus) {
                      canRequestNotifier.value = false;
                    } else {
                      if (Navigator.canPop(context)) {
                        Navigator.pop(context);
                      }
                    }
                  },
                  child: child!,
                );
              },
              child: ValueListenableBuilder(
                valueListenable: canRequestNotifier,
                builder: (context, value, child) {
                  final specificTextcolor = colorManager.getSpecificTextColor();
                  return Theme(
                    data: Theme.of(context).copyWith(
                      textSelectionTheme: TextSelectionThemeData(
                        selectionColor: specificTextcolor.withAlpha(50),
                        cursorColor: specificTextcolor,
                        selectionHandleColor: specificTextcolor,
                      ),
                    ),
                    child: TextField(
                      focusNode: textFieldNode,
                      autofocus: widget.autoFocus,
                      canRequestFocus: isTV ? value : true,
                      keyboardType: widget.onlyNumber ? .number : null,
                      minLines: widget.expand ? 3 : 1,
                      maxLines: widget.expand ? null : 1,
                      style: TextStyle(fontSize: 12),
                      controller: widget.controller,
                      decoration: InputDecoration(
                        visualDensity: widget.compact
                            ? .new(vertical: -2.5)
                            : null,
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: specificTextcolor),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: specificTextcolor,
                            width: 1.5,
                          ),
                        ),
                        isDense: true,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}
