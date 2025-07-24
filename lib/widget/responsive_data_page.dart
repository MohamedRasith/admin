import 'package:flutter/material.dart';

class ResponsiveDataTablePage extends StatelessWidget {
  const ResponsiveDataTablePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Responsive DataTable"),
        centerTitle: true,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isSmallScreen = constraints.maxWidth < 600;

          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: DataTable(
                columnSpacing: 24,
                headingRowColor:
                MaterialStateProperty.all(Colors.grey.shade200),
                columns: [
                  const DataColumn(label: Text("ID")),
                  const DataColumn(label: Text("Name")),
                  if (!isSmallScreen)
                    const DataColumn(label: Text("Email")),
                  if (!isSmallScreen)
                    const DataColumn(label: Text("Role")),
                  const DataColumn(label: Text("Status")),
                ],
                rows: List.generate(
                  20,
                      (index) => DataRow(cells: [
                    DataCell(Text("${index + 1}")),
                    DataCell(Text("User $index")),
                    if (!isSmallScreen)
                      DataCell(Text("user$index@example.com")),
                    if (!isSmallScreen)
                      DataCell(Text(index % 2 == 0 ? "Admin" : "User")),
                    DataCell(
                      Chip(
                        label: Text(index % 3 == 0 ? "Inactive" : "Active"),
                        backgroundColor: index % 3 == 0
                            ? Colors.red.shade100
                            : Colors.green.shade100,
                        labelStyle: TextStyle(
                          color: index % 3 == 0
                              ? Colors.red.shade700
                              : Colors.green.shade700,
                        ),
                      ),
                    ),
                  ]),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}