import 'package:finroot_mobile/design/design.dart';
import 'package:finroot_mobile/navigation/two_pane.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) =>
    MaterialApp(theme: AppTheme.light, home: Scaffold(body: child));

void main() {
  testWidgets('shows the placeholder while nothing is selected', (tester) async {
    await tester.pumpWidget(
      _host(
        const TwoPane(
          list: Text('LIST'),
          detail: null,
          placeholder: PaneWaiting(message: 'Pick one'),
        ),
      ),
    );

    expect(find.text('LIST'), findsOneWidget);
    expect(find.text('Pick one'), findsOneWidget);
  });

  testWidgets('falls back to a generic waiting state with no placeholder', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(const TwoPane(list: Text('LIST'), detail: null)),
    );

    expect(find.text('Select an item to see its details.'), findsOneWidget);
  });

  testWidgets('renders the detail when one is provided', (tester) async {
    await tester.pumpWidget(
      _host(
        const TwoPane(
          list: Text('LIST'),
          detail: Text('DETAIL'),
          placeholder: PaneWaiting(message: 'Pick one'),
        ),
      ),
    );

    expect(find.text('LIST'), findsOneWidget);
    expect(find.text('DETAIL'), findsOneWidget);
    expect(find.text('Pick one'), findsNothing);
  });

  testWidgets('the list pane keeps its fixed width', (tester) async {
    const key = Key('list-pane-content');
    await tester.pumpWidget(
      _host(
        const TwoPane(
          list: SizedBox.expand(key: key),
          detail: Text('DETAIL'),
        ),
      ),
    );

    expect(
      tester.getSize(find.byKey(key)).width,
      AppBreakpoints.listPaneWidth,
    );
  });
}
