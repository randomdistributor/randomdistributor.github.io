import '../widgets/product_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../main.dart';
import '../services/images.dart';

class ProductFormScreen extends StatefulWidget {
  final Map<String, dynamic>? product;
  const ProductFormScreen({super.key, this.product});

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  String? _supplierId;
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _brands = [];

  // images
  final List<Map<String, dynamic>> _existing = []; // {id, url}
  final List<String> _newUrls = [];

  late final _code = TextEditingController(text: widget.product?['product_code']);
  late final _desc = TextEditingController(text: widget.product?['description']);
  late final _unit = TextEditingController(text: widget.product?['unit'] ?? 'pcs');
  late final _qty = TextEditingController(text: '${widget.product?['available_qty'] ?? 0}');
  late final _price = TextEditingController(text: '${widget.product?['supplier_price'] ?? ''}');
  late final _carton = TextEditingController(text: '${widget.product?['units_per_carton'] ?? 1}');
  late final _moq = TextEditingController(text: '${widget.product?['moq'] ?? 1}');

  String? _categoryId;
  String? _brandId;
  String _saleMode = 'loose_allowed';

  bool _loading = true;
  bool _busy = false;
  bool _uploading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _categoryId = widget.product?['category_id'];
    _brandId = widget.product?['brand_id'];
    _saleMode = widget.product?['sale_mode'] ?? 'loose_allowed';
    _init();
  }

  Future<void> _init() async {
    final uid = supabase.auth.currentUser!.id;
    final me = await supabase.from('suppliers').select('id').eq('profile_id', uid).maybeSingle();
    _supplierId = me?['id'] as String?;
    _categories = ((await supabase.from('categories').select('id, name').order('name')) as List)
        .cast<Map<String, dynamic>>();
    _brands = ((await supabase.from('brands').select('id, name').order('name')) as List)
        .cast<Map<String, dynamic>>();
    if (widget.product != null) {
      final imgs = await supabase
          .from('product_images')
          .select('id, url')
          .eq('product_id', widget.product!['id']);
      _existing.addAll((imgs as List).cast<Map<String, dynamic>>());
    }
    setState(() => _loading = false);
  }

  /// Lets the supplier create a category/brand that doesn't exist yet.
  Future<void> _createRef({required bool isCategory}) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isCategory ? 'New category' : 'New brand'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: isCategory ? 'Category name' : 'Brand name'),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;

    final table = isCategory ? 'categories' : 'brands';
    try {
      final row = await supabase.from(table).insert({'name': name}).select('id, name').single();
      setState(() {
        if (isCategory) {
          _categories = [..._categories, row]..sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
          _categoryId = row['id'] as String;
        } else {
          _brands = [..._brands, row]..sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
          _brandId = row['id'] as String;
        }
      });
    } catch (e) {
      // Most likely a duplicate name — reuse the existing row instead.
      final existing = await supabase.from(table).select('id, name').ilike('name', name).maybeSingle();
      if (existing != null) {
        setState(() {
          if (isCategory) {
            _categoryId = existing['id'] as String;
          } else {
            _brandId = existing['id'] as String;
          }
        });
      } else if (mounted) {
        setState(() => _error = 'Could not add ${isCategory ? 'category' : 'brand'}: $e');
      }
    }
  }

  Future<void> _addImage(ImageSource source) async {
    setState(() => _uploading = true);
    try {
      final url = await ImageService.pickAndUpload(
        bucket: 'product-images',
        folder: _supplierId ?? 'products',
        source: source,
      );
      if (url != null) setState(() => _newUrls.add(url));
    } catch (e) {
      setState(() => _error = 'Image upload failed: $e');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _pickSource() {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(children: [
          ListTile(
            leading: const Icon(Icons.photo_camera),
            title: const Text('Camera'),
            onTap: () {
              Navigator.pop(context);
              _addImage(ImageSource.camera);
            },
          ),
          ListTile(
            leading: const Icon(Icons.photo_library),
            title: const Text('Gallery'),
            onTap: () {
              Navigator.pop(context);
              _addImage(ImageSource.gallery);
            },
          ),
        ]),
      ),
    );
  }

  Future<void> _deleteExisting(Map<String, dynamic> img) async {
    await supabase.from('product_images').delete().eq('id', img['id']);
    setState(() => _existing.remove(img));
  }

  Future<void> _save() async {
    final price = double.tryParse(_price.text.trim());
    if (_code.text.trim().isEmpty || price == null) {
      setState(() => _error = 'Product code and supplier price are required');
      return;
    }
    if (_supplierId == null) {
      setState(() => _error = 'Your supplier account is not linked. Contact admin.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final payload = {
      'supplier_id': _supplierId,
      'product_code': _code.text.trim(),
      'description': _desc.text.trim().isEmpty ? null : _desc.text.trim(),
      'category_id': _categoryId,
      'brand_id': _brandId,
      'unit': _unit.text.trim().isEmpty ? 'pcs' : _unit.text.trim(),
      'available_qty': int.tryParse(_qty.text.trim()) ?? 0,
      'supplier_price': price,
      'units_per_carton': int.tryParse(_carton.text.trim()) ?? 1,
      'sale_mode': _saleMode,
      'moq': int.tryParse(_moq.text.trim()) ?? 1,
    };
    try {
      String productId;
      if (widget.product == null) {
        final row = await supabase.from('products').insert(payload).select('id').single();
        productId = row['id'] as String;
      } else {
        productId = widget.product!['id'] as String;
        await supabase.from('products').update(payload).eq('id', productId);
      }

      if (_newUrls.isNotEmpty) {
        final hasExisting = _existing.isNotEmpty;
        final rows = <Map<String, dynamic>>[];
        for (var i = 0; i < _newUrls.length; i++) {
          rows.add({
            'product_id': productId,
            'url': _newUrls[i],
            'is_primary': !hasExisting && i == 0,
            'sort_order': _existing.length + i,
          });
        }
        await supabase.from('product_images').insert(rows);
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.product == null ? 'Add product' : 'Edit product')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _imageStrip(),
                const SizedBox(height: 16),
                TextField(controller: _code, decoration: const InputDecoration(labelText: 'Product code *')),
                const SizedBox(height: 12),
                TextField(controller: _desc, decoration: const InputDecoration(labelText: 'Description')),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _categoryId,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Category'),
                      items: [
                        for (final c in _categories)
                          DropdownMenuItem(value: c['id'] as String, child: Text(c['name'])),
                      ],
                      onChanged: (v) => setState(() => _categoryId = v),
                    ),
                  ),
                  IconButton(
                    tooltip: 'New category',
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: () => _createRef(isCategory: true),
                  ),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _brandId,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Brand'),
                      items: [
                        for (final b in _brands)
                          DropdownMenuItem(value: b['id'] as String, child: Text(b['name'])),
                      ],
                      onChanged: (v) => setState(() => _brandId = v),
                    ),
                  ),
                  IconButton(
                    tooltip: 'New brand',
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: () => _createRef(isCategory: false),
                  ),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: TextField(controller: _qty, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Available qty'))),
                  const SizedBox(width: 12),
                  Expanded(child: TextField(controller: _price, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Supplier price *'))),
                  const SizedBox(width: 12),
                  Expanded(child: TextField(controller: _unit, decoration: const InputDecoration(labelText: 'Unit'))),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _saleMode,
                      decoration: const InputDecoration(labelText: 'Sale mode'),
                      items: const [
                        DropdownMenuItem(value: 'loose_allowed', child: Text('Loose allowed')),
                        DropdownMenuItem(value: 'carton_only', child: Text('Carton only')),
                      ],
                      onChanged: (v) => setState(() => _saleMode = v!),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: TextField(controller: _carton, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Units/carton'))),
                  const SizedBox(width: 12),
                  Expanded(child: TextField(controller: _moq, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'MOQ'))),
                ]),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ],
              ],
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton(
            onPressed: _busy ? null : _save,
            child: _busy
                ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Save product'),
          ),
        ),
      ),
    );
  }

  Widget _imageStrip() {
    return SizedBox(
      height: 92,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final img in _existing) _thumb(img['url'] as String?, onDelete: () => _deleteExisting(img)),
          for (final url in _newUrls)
            _thumb(url, onDelete: () => setState(() => _newUrls.remove(url))),
          _addTile(),
        ],
      ),
    );
  }

  Widget _thumb(String? url, {required VoidCallback onDelete}) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 88,
              height: 88,
              child: ProductImage(url: url),
            ),
          ),
          Positioned(
            right: 2,
            top: 2,
            child: GestureDetector(
              onTap: onDelete,
              child: const CircleAvatar(
                radius: 11,
                backgroundColor: Colors.black54,
                child: Icon(Icons.close, size: 14, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _addTile() {
    return GestureDetector(
      onTap: _uploading ? null : _pickSource,
      child: Container(
        width: 88,
        height: 88,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Theme.of(context).colorScheme.primary),
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.06),
        ),
        child: _uploading
            ? const Center(child: SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2)))
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_a_photo, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(height: 4),
                  Text('Add', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 12)),
                ],
              ),
      ),
    );
  }
}
