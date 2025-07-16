import 'package:flutter/material.dart';

class ProductDashboard extends StatelessWidget {
  const ProductDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: Drawer(child: _buildSidebar()),
      appBar: AppBar(
        title: const Text("Products"),
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.import_export)),
          IconButton(onPressed: () {}, icon: const Icon(Icons.more_vert)),
          ElevatedButton(onPressed: () {}, child: const Text("Add Product")),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth > 800) {
            return _buildTableView();
          } else {
            return _buildListView(); // mobile
          }
        },
      ),
    );
  }

  Widget _buildSidebar() {
    return ListView(
      children: const [
        DrawerHeader(child: Text("Menu")),
        ListTile(title: Text("Home")),
        ListTile(title: Text("Orders")),
        ListTile(title: Text("Products")),
        ListTile(title: Text("Analytics")),
      ],
    );
  }

  Widget _buildTableView() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(columns: const [
        DataColumn(label: Text("Product Title")),
        DataColumn(label: Text("Status")),
        DataColumn(label: Text("Inventory")),
        DataColumn(label: Text("Sales")),
        DataColumn(label: Text("Markets")),
        DataColumn(label: Text("Category")),
        DataColumn(label: Text("Type")),
        DataColumn(label: Text("Vendor")),
      ], rows: _mockRows()),
    );
  }

  Widget _buildListView() {
    return ListView.builder(
      itemCount: 5,
      itemBuilder: (context, index) => ListTile(
        leading: Checkbox(value: false, onChanged: (_) {}),
        title: const Text("GC Beauty Care Face Mud Mask – Zaffron"),
        subtitle: const Text("Status: Active\nInventory: 0 in stock"),
        trailing: const Icon(Icons.more_vert),
      ),
    );
  }

  List<DataRow> _mockRows() {
    return List.generate(5, (index) {
      return DataRow(cells: [
        DataCell(Row(children: [
          Image.network(
            "https://images.pexels.com/photos/2536965/pexels-photo-2536965.jpeg",
            width: 40,
          ),
          const SizedBox(width: 8),
          const Text("Face Mud Mask – Zaffron (500ml)")
        ])),
        const DataCell(Text("Active")),
        const DataCell(Text("0 in stock")),
        const DataCell(Text("4")),
        const DataCell(Text("2")),
        const DataCell(Text("Skin Care Masks & Peels")),
        const DataCell(Text("Face Mud Mask")),
        const DataCell(Text("GC Beauty Care")),
      ]);
    });
  }
}
