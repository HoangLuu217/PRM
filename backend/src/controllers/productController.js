import { Product, Menu, Branch, Business } from '../models/index.js';

// @desc    Get products by menu, branch, or business
// @route   GET /api/products
// @access  Public
export const getProducts = async (req, res) => {
  try {
    const { branchId, menuId, businessId, category, includeUnavailable } = req.query;
    const query = {};

    if (includeUnavailable !== 'true') {
      query.isAvailable = true;
    }
    if (branchId) query.branchId = branchId;
    if (menuId) query.menuId = menuId;
    if (category) query.category = category;

    if (businessId) {
      const [menus, branches] = await Promise.all([
        Menu.find({ businessId }).select('_id'),
        Branch.find({ businessId }).select('_id'),
      ]);
      const menuIds = menus.map((m) => m._id);
      const branchIds = branches.map((b) => b._id);
      query.$or = [
        { menuId: { $in: menuIds } },
        { branchId: { $in: branchIds } },
      ];
    }

    const products = await Product.find(query).sort({ category: 1, name: 1 });

    res.json({
      success: true,
      count: products.length,
      data: products,
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// @desc    Get single product
// @route   GET /api/products/:id
// @access  Public
export const getProductById = async (req, res) => {
  try {
    const product = await Product.findById(req.params.id);
    if (!product) {
      return res.status(404).json({ success: false, message: 'Không tìm thấy món ăn/đồ uống' });
    }

    res.json({
      success: true,
      data: product,
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// @desc    Create new product
// @route   POST /api/products
// @access  Private (Owner/Staff)
export const createProduct = async (req, res) => {
  try {
    const { menuId, branchId, category, name, description, price, imageUrl, sizes, options } = req.body;

    // Check Business Subscription Menu Item Limits
    let targetBusiness = null;
    if (branchId) {
      const br = await Branch.findById(branchId).populate('businessId');
      targetBusiness = br?.businessId;
    } else if (menuId) {
      const mn = await Menu.findById(menuId).populate('businessId');
      targetBusiness = mn?.businessId;
    }

    if (targetBusiness) {
      const maxMenuItems = targetBusiness.subscription?.features?.maxMenuItems || 15;
      const countQuery = branchId ? { branchId } : (menuId ? { menuId } : {});
      const currentProductsCount = await Product.countDocuments(countQuery);

      if (currentProductsCount >= maxMenuItems) {
        return res.status(403).json({
          success: false,
          message: `Quán của bạn đang ở gói ${targetBusiness.subscription?.plan || 'STARTER'} (giới hạn tối đa ${maxMenuItems} món trong thực đơn). Vui lòng nâng cấp gói PRO VIP để thêm không giới hạn thực đơn!`,
          requiresUpgrade: true,
        });
      }
    }

    let basePrice = Number(price) || 0;
    if (sizes && sizes.length > 0) {
      const defaultSize = sizes.find((s) => s.isDefault) || sizes[0];
      if (!basePrice || basePrice === 0) {
        basePrice = defaultSize.price;
      }
    }

    const product = await Product.create({
      menuId,
      branchId,
      category,
      name,
      description,
      price: basePrice,
      imageUrl: '',
      sizes: sizes || [],
      options: options || [],
    });

    res.status(201).json({
      success: true,
      data: product,
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// @desc    Create batch products into menu
// @route   POST /api/products/batch
// @access  Private (Owner/Staff)
export const createBatchProducts = async (req, res) => {
  try {
    const { branchId, menuId: reqMenuId, products } = req.body;
    if (!products || !Array.isArray(products) || products.length === 0) {
      return res.status(400).json({ success: false, message: 'Danh sách món cần nhập không được rỗng' });
    }

    // Resolve a valid Menu document
    let targetMenu = null;
    if (reqMenuId) {
      targetMenu = await Menu.findById(reqMenuId);
    }
    if (!targetMenu && branchId) {
      targetMenu = await Menu.findOne({ branchId, status: 'ACTIVE' });
      if (!targetMenu) {
        const branch = await Branch.findById(branchId);
        if (branch) {
          targetMenu = await Menu.findOne({ businessId: branch.businessId, status: 'ACTIVE' });
          if (!targetMenu) {
            targetMenu = await Menu.create({
              businessId: branch.businessId,
              branchId: branch._id,
              name: 'Thực đơn chính',
              status: 'ACTIVE',
            });
          }
        }
      }
    }

    const resolvedMenuId = targetMenu?._id || reqMenuId;

    const toInsert = products
      .filter((p) => p && p.name && String(p.name).trim())
      .map((p) => {
        let basePrice = Number(p.price) || 0;
        if (p.sizes && p.sizes.length > 0) {
          const defaultSize = p.sizes.find((s) => s.isDefault) || p.sizes[0];
          if (!basePrice || basePrice === 0) {
            basePrice = defaultSize.price;
          }
        }
        return {
          menuId: resolvedMenuId,
          branchId: branchId || targetMenu?.branchId,
          category: p.category || 'Đồ Uống',
          name: String(p.name).trim(),
          description: p.description || '',
          price: basePrice,
          imageUrl: '',
          sizes: p.sizes || [],
          options: p.options || [],
          isAvailable: p.isAvailable !== false,
        };
      });

    if (toInsert.length === 0) {
      return res.status(400).json({ success: false, message: 'Không có món ăn hợp lệ để thêm' });
    }

    const created = await Product.insertMany(toInsert);

    res.status(201).json({
      success: true,
      count: created.length,
      data: created,
    });
  } catch (error) {
    console.error('Batch create products error:', error);
    res.status(500).json({ success: false, message: error.message });
  }
};

// @desc    Update product
// @route   PUT /api/products/:id
// @access  Private (Owner/Staff)
export const updateProduct = async (req, res) => {
  try {
    const updateData = { ...req.body };
    updateData.imageUrl = '';
    if (updateData.sizes && updateData.sizes.length > 0) {
      if (!updateData.price || Number(updateData.price) === 0) {
        const defaultSize = updateData.sizes.find((s) => s.isDefault) || updateData.sizes[0];
        updateData.price = defaultSize.price;
      }
    }

    const product = await Product.findByIdAndUpdate(req.params.id, updateData, { new: true });
    if (!product) {
      return res.status(404).json({ success: false, message: 'Không tìm thấy món ăn' });
    }

    res.json({
      success: true,
      data: product,
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// @desc    Delete product
// @route   DELETE /api/products/:id
// @access  Private (Owner/Staff)
export const deleteProduct = async (req, res) => {
  try {
    const product = await Product.findByIdAndDelete(req.params.id);
    if (!product) {
      return res.status(404).json({ success: false, message: 'Không tìm thấy món ăn để xóa' });
    }

    res.json({
      success: true,
      message: 'Đã xóa món ăn thành công',
      data: { id: req.params.id },
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};
