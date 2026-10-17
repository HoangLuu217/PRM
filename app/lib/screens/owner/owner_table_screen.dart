import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/table_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/table_provider.dart';

class OwnerTableScreen extends StatefulWidget {
  const OwnerTableScreen({super.key});

  @override
  State<OwnerTableScreen> createState() => _OwnerTableScreenState();
}

class _OwnerTableScreenState extends State<OwnerTableScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<String> _tabs = [
    'Tất cả',
    'Bàn trống',
    'Đã đặt trước',
    'Đang có khách',
    'Bảo trì',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTables();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String? _getOwnerBranchId() {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    if (user?.business != null) {
      final biz = user!.business!;
      if (biz['branches'] is List && (biz['branches'] as List).isNotEmpty) {
        final b = (biz['branches'] as List)[0];
        if (b is Map) return (b['_id'] ?? b['id'])?.toString();
      }
      if (biz['primaryBranch'] is Map) {
        return (biz['primaryBranch']['_id'] ?? biz['primaryBranch']['id'])?.toString();
      }
      return (biz['_id'] ?? biz['id'])?.toString();
    }
    return null;
  }

  void _loadTables() {
    final branchId = _getOwnerBranchId();
    Provider.of<TableProvider>(context, listen: false).fetchTables(branchId: branchId);
  }

  List<TableModel> _filterTables(List<TableModel> list, int tabIndex) {
    switch (tabIndex) {
      case 1:
        return list.where((t) => t.status == 'AVAILABLE').toList();
      case 2:
        return list.where((t) => t.status == 'RESERVED').toList();
      case 3:
        return list.where((t) => t.status == 'UNAVAILABLE').toList();
      case 4:
        return list.where((t) => t.status == 'MAINTENANCE').toList();
      default:
        return list;
    }
  }

  void _showAddEditTableDialog({TableModel? tableToEdit}) {
    final isEditing = tableToEdit != null;
    final nameController = TextEditingController(text: tableToEdit?.name ?? '');
    final capacityController = TextEditingController(text: tableToEdit != null ? '${tableToEdit.capacity}' : '4');
    final locationController = TextEditingController(text: tableToEdit?.location ?? 'Tầng 1');
    String selectedStatus = tableToEdit?.status ?? 'AVAILABLE';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            isEditing ? 'Sửa thông tin bàn ăn' : 'Thêm bàn ăn mới',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Tên bàn
                const Text('Tên / Số bàn:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    hintText: 'Ví dụ: Bàn A01, VIP 1...',
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                ),
                const SizedBox(height: 14),

                // Sức chứa
                const Text('Sức chứa (số người):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                TextField(
                  controller: capacityController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: 'Ví dụ: 4',
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                ),
                const SizedBox(height: 14),

                // Vị trí / Khu vực
                const Text('Khu vực / Vị trí:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                TextField(
                  controller: locationController,
                  decoration: InputDecoration(
                    hintText: 'Ví dụ: Tầng 1, Sân vườn, Phòng VIP...',
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                ),
                const SizedBox(height: 14),

                // Trạng thái bàn
                const Text('Trạng thái bàn:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: selectedStatus,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'AVAILABLE', child: Text('Bàn trống (Available)')),
                    DropdownMenuItem(value: 'RESERVED', child: Text('Đã đặt trước (Reserved)')),
                    DropdownMenuItem(value: 'UNAVAILABLE', child: Text('Đang có khách (Unavailable)')),
                    DropdownMenuItem(value: 'MAINTENANCE', child: Text('Bảo trì / Tạm khóa')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => selectedStatus = val);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                final capacity = int.tryParse(capacityController.text.trim()) ?? 2;
                final location = locationController.text.trim();
                final branchId = _getOwnerBranchId() ?? '';

                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Vui lòng nhập tên bàn')),
                  );
                  return;
                }

                Navigator.pop(ctx);
                final provider = Provider.of<TableProvider>(context, listen: false);

                if (isEditing) {
                  final res = await provider.updateTable(
                    tableToEdit.id,
                    name: name,
                    capacity: capacity,
                    location: location,
                    status: selectedStatus,
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(res['message'] ?? 'Cập nhật thành công'),
                        backgroundColor: res['success'] == true ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                      ),
                    );
                  }
                } else {
                  final res = await provider.createTable(
                    branchId: branchId,
                    name: name,
                    capacity: capacity,
                    location: location,
                    status: selectedStatus,
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(res['message'] ?? 'Thêm bàn thành công'),
                        backgroundColor: res['success'] == true ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0072FF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(isEditing ? 'Lưu thay đổi' : 'Thêm bàn'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteTable(TableModel table) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Xóa bàn ${table.name}?'),
        content: Text('Bạn có chắc chắn muốn xóa bàn "${table.name}" (${table.capacity} người) không? Hành động này không thể hoàn tác.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final res = await Provider.of<TableProvider>(context, listen: false).deleteTable(table.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(res['message'] ?? 'Đã xóa bàn thành công'),
                    backgroundColor: res['success'] == true ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), foregroundColor: Colors.white),
            child: const Text('Xác nhận xóa'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tableProvider = Provider.of<TableProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Quản lý Bàn ăn', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0.5,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: const Color(0xFF0072FF),
          unselectedLabelColor: const Color(0xFF64748B),
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
          indicatorColor: const Color(0xFF0072FF),
          indicatorWeight: 3,
          tabs: _tabs.map((title) => Tab(text: title)).toList(),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditTableDialog(),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Thêm bàn mới', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0072FF),
      ),
      body: TabBarView(
        controller: _tabController,
        children: List.generate(_tabs.length, (tabIndex) {
          final filtered = _filterTables(tableProvider.tables, tabIndex);

          if (tableProvider.isLoading && tableProvider.tables.isEmpty) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF0072FF)));
          }

          if (filtered.isEmpty) {
            return RefreshIndicator(
              onRefresh: () async => _loadTables(),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.25),
                  Center(
                    child: Column(
                      children: [
                        const Icon(Icons.table_restaurant_outlined, size: 48, color: Color(0xFF94A3B8)),
                        const SizedBox(height: 12),
                        const Text('Chưa có bàn nào trong danh mục này', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                        const SizedBox(height: 6),
                        const Text('Nhấn "Thêm bàn mới" để tạo bàn cho quán', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => _loadTables(),
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
              itemCount: filtered.length,
              itemBuilder: (ctx, i) {
                final tbl = filtered[i];
                return _buildTableCard(tbl);
              },
            ),
          );
        }),
      ),
    );
  }

  Widget _buildTableCard(TableModel tbl) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Icon bàn với màu sắc trạng thái
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: tbl.statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.table_restaurant_rounded, color: tbl.statusColor, size: 26),
          ),
          const SizedBox(width: 14),

          // Tên bàn, số người, vị trí
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      tbl.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: tbl.statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        tbl.statusLabel,
                        style: TextStyle(color: tbl.statusColor, fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.people_alt_outlined, size: 14, color: Color(0xFF64748B)),
                    const SizedBox(width: 4),
                    Text('${tbl.capacity} người', style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                    const SizedBox(width: 12),
                    const Icon(Icons.layers_outlined, size: 14, color: Color(0xFF64748B)),
                    const SizedBox(width: 4),
                    Text(tbl.location, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                  ],
                ),
              ],
            ),
          ),

          // Nút sửa / xóa
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 20, color: Color(0xFF0072FF)),
            tooltip: 'Sửa bàn',
            onPressed: () => _showAddEditTableDialog(tableToEdit: tbl),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20, color: Color(0xFFEF4444)),
            tooltip: 'Xóa bàn',
            onPressed: () => _confirmDeleteTable(tbl),
          ),
        ],
      ),
    );
  }
}
