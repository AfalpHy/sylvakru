part of '../../layer/license_layer.dart';

extension _LicensePage on _LicenseLayerState {
  Widget pageView(BuildContext context) {
    return myScaffold(
      context: context,
      body: pageContent(),
      label: 'settings',
      actions: [
        MySearchField(
          hintText: AppLocalizations.of(context).searchLicenses,
          textController: textController,
        ),
      ],
    );
  }

  Widget pageContent() {
    return ListView.builder(
      padding: .only(left: 5),
      itemCount: packages.length + 1,
      itemBuilder: (context, index) {
        if (index >= packages.length) {
          return SizedBox(height: 90);
        }
        final pkg = packages[index];

        return ListenableBuilder(
          listenable: Listenable.merge([
            iconColor.valueNotifier,
            textColor.valueNotifier,
          ]),
          builder: (context, _) {
            return ExpansionTile(
              iconColor: iconColor.value,
              collapsedIconColor: iconColor.value,
              title: Text(pkg, style: .new(color: textColor.value)),
              children: [SizedBox(height: 500, child: buildLicenseDetail(pkg))],
            );
          },
        );
      },
    );
  }
}
