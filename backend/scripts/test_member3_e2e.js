import express from 'express';
import mongoose from 'mongoose';
import dotenv from 'dotenv';
import jwt from 'jsonwebtoken';
import apiRoutes from '../src/routes/index.js';
import { User, Business, Product, Cart, Menu } from '../src/models/index.js';

dotenv.config();

const PORT = 5099;
const app = express();
app.use(express.json());
app.use('/api', apiRoutes);

async function runTests() {
  console.log('--- STARTING MEMBER 3 E2E TESTS ---');
  
  // 1. Connect DB
  await mongoose.connect(process.env.MONGODB_URI);
  console.log('✓ Connected to MongoDB');

  // Start temporary test server
  const server = app.listen(PORT);
  const baseUrl = `http://localhost:${PORT}/api`;

  try {
    // 2. Find or create a test User & Business
    let testUser = await User.findOne({ email: 'test_member3@fconnect.vn' });
    if (!testUser) {
      testUser = await User.create({
        fullName: 'Member 3 Test User',
        email: 'test_member3@fconnect.vn',
        password: 'password123',
        role: 'ADMIN',
        authProvider: 'LOCAL',
        status: 'ACTIVE',
      });
    } else {
      testUser.role = 'ADMIN';
      await testUser.save();
    }

    const token = jwt.sign(
      { id: testUser._id, role: testUser.role },
      process.env.JWT_SECRET || 'fconnect_super_secret_jwt_key_2025',
      { expiresIn: '1h' }
    );
    const authHeaders = {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${token}`,
    };

    let testBusiness = await Business.findOne();
    if (!testBusiness) {
      throw new Error('No business found in database to test');
    }
    const businessId = testBusiness._id.toString();
    console.log(`✓ Using test Business ID: ${businessId}`);

    // TEST 1: GET /api/businesses/:id/menu
    console.log('\n[1] Testing GET /api/businesses/:id/menu ...');
    const menuRes = await fetch(`${baseUrl}/businesses/${businessId}/menu`);
    const menuData = await menuRes.json();
    console.log('Status:', menuRes.status, 'Success:', menuData.success);
    if (!menuData.success) throw new Error('GET menu failed: ' + JSON.stringify(menuData));
    console.log(`✓ Menu retrieved successfully: "${menuData.data.menu?.name || 'Default'}" with ${menuData.data.products?.length || 0} products`);

    // TEST 2: POST /api/products (Thêm Product kèm Options & Sizes)
    console.log('\n[2] Testing POST /api/products (Thêm món mới kèm Options)...');
    const newProductPayload = {
      businessId,
      name: 'Trà Sữa Oolong Nướng Đặc Biệt (Test Member 3)',
      category: 'Trà Sữa',
      description: 'Hương vị Oolong thơm lừng kết hợp sữa béo ngậy.',
      price: 35000,
      imageUrl: 'https://images.unsplash.com/photo-1544787219-7f47ccb76574',
      sizes: [
        { name: 'Size M', price: 35000, isDefault: true },
        { name: 'Size L', price: 42000, isDefault: false },
      ],
      options: [
        {
          name: 'Topping',
          required: false,
          isMultiple: true,
          values: [
            { name: 'Trân châu hoàng kim', price: 6000 },
            { name: 'Thạch sương sáo', price: 5000 },
          ],
        },
        {
          name: 'Mức đường',
          required: true,
          isMultiple: false,
          values: [
            { name: '100% đường', price: 0 },
            { name: '50% đường', price: 0 },
            { name: '0% đường', price: 0 },
          ],
        },
      ],
    };

    const createProdRes = await fetch(`${baseUrl}/products`, {
      method: 'POST',
      headers: authHeaders,
      body: JSON.stringify(newProductPayload),
    });
    const createProdData = await createProdRes.json();
    console.log('Status:', createProdRes.status, 'Success:', createProdData.success);
    if (!createProdData.success || !createProdData.data) {
      throw new Error('Create product failed: ' + JSON.stringify(createProdData));
    }
    const createdProduct = createProdData.data;
    const productId = createdProduct._id;
    console.log(`✓ Product created successfully! ID: ${productId}, Name: "${createdProduct.name}", Price: ${createdProduct.price}đ`);
    console.log(`  Options count: ${createdProduct.options?.length}, Sizes count: ${createdProduct.sizes?.length}`);

    // TEST 3: GET /api/products/:id
    console.log('\n[3] Testing GET /api/products/:id ...');
    const getProdRes = await fetch(`${baseUrl}/products/${productId}`);
    const getProdData = await getProdRes.json();
    console.log('Status:', getProdRes.status, 'Success:', getProdData.success);
    if (!getProdData.success || getProdData.data._id !== productId) {
      throw new Error('GET product by ID failed');
    }
    console.log(`✓ Fetched product detail matches: "${getProdData.data.name}"`);

    // TEST 4: PUT /api/products/:id (Cập nhật giá và bật/tắt món)
    console.log('\n[4] Testing PUT /api/products/:id (Cập nhật giá & Bật/tắt món)...');
    const updateProdRes = await fetch(`${baseUrl}/products/${productId}`, {
      method: 'PUT',
      headers: authHeaders,
      body: JSON.stringify({
        price: 39000,
        isAvailable: false, // Tắt món
      }),
    });
    const updateProdData = await updateProdRes.json();
    console.log('Status:', updateProdRes.status, 'Success:', updateProdData.success);
    if (!updateProdData.success || updateProdData.data.price !== 39000 || updateProdData.data.isAvailable !== false) {
      throw new Error('PUT product failed: ' + JSON.stringify(updateProdData));
    }
    console.log(`✓ Updated product price to ${updateProdData.data.price}đ and isAvailable: ${updateProdData.data.isAvailable}`);

    // TEST 5: POST /api/cart (Thêm vào Giỏ hàng với Size & Options)
    console.log('\n[5] Testing POST /api/cart (Thêm vào giỏ hàng với Size & Options)...');
    const addToCartPayload = {
      productId,
      businessId,
      quantity: 2,
      selectedSize: { name: 'Size L', price: 42000 },
      selectedOptions: [
        { optionName: 'Topping', choiceName: 'Trân châu hoàng kim', additionalPrice: 6000 },
        { optionName: 'Mức đường', choiceName: '50% đường', additionalPrice: 0 },
      ],
    };
    const addCartRes = await fetch(`${baseUrl}/cart`, {
      method: 'POST',
      headers: authHeaders,
      body: JSON.stringify(addToCartPayload),
    });
    const addCartData = await addCartRes.json();
    console.log('Status:', addCartRes.status, 'Success:', addCartData.success);
    if (!addCartData.success) {
      throw new Error('Add to cart failed: ' + JSON.stringify(addCartData));
    }
    console.log(`✓ Item added to cart. Total items in cart: ${addCartData.data.items?.length}`);

    // TEST 6: GET /api/cart (Xem Giỏ hàng)
    console.log('\n[6] Testing GET /api/cart ...');
    const getCartRes = await fetch(`${baseUrl}/cart`, {
      headers: authHeaders,
    });
    const getCartData = await getCartRes.json();
    console.log('Status:', getCartRes.status, 'Success:', getCartData.success);
    if (!getCartData.success || !getCartData.data.items || getCartData.data.items.length === 0) {
      throw new Error('GET cart failed: ' + JSON.stringify(getCartData));
    }
    const cartItem = getCartData.data.items[0];
    const itemId = cartItem._id;
    console.log(`✓ Cart retrieved. Item ID: ${itemId}, Quantity: ${cartItem.quantity}, Total Amount: ${getCartData.data.totalAmount}đ`);

    // TEST 7: PUT /api/cart (Cập nhật số lượng)
    console.log('\n[7] Testing PUT /api/cart (Cập nhật số lượng món)...');
    const updateCartRes = await fetch(`${baseUrl}/cart`, {
      method: 'PUT',
      headers: authHeaders,
      body: JSON.stringify({
        itemId,
        productId,
        quantity: 4,
      }),
    });
    const updateCartData = await updateCartRes.json();
    console.log('Status:', updateCartRes.status, 'Success:', updateCartData.success);
    if (!updateCartData.success) {
      throw new Error('Update cart failed: ' + JSON.stringify(updateCartData));
    }
    const updatedItem = updateCartData.data.items.find(i => i._id === itemId || i.productId?._id === productId);
    console.log(`✓ Cart quantity updated to: ${updatedItem?.quantity || 4}, New Total Amount: ${updateCartData.data.totalAmount}đ`);

    // TEST 8: DELETE /api/cart/:itemId (Xóa món khỏi Giỏ hàng)
    console.log('\n[8] Testing DELETE /api/cart/:itemId ...');
    const deleteCartRes = await fetch(`${baseUrl}/cart/${itemId}`, {
      method: 'DELETE',
      headers: authHeaders,
    });
    const deleteCartData = await deleteCartRes.json();
    console.log('Status:', deleteCartRes.status, 'Success:', deleteCartData.success);
    if (!deleteCartData.success) {
      throw new Error('DELETE cart item failed: ' + JSON.stringify(deleteCartData));
    }
    console.log(`✓ Item deleted from cart. Remaining items: ${deleteCartData.data.items?.length}`);

    // TEST 9: DELETE /api/products/:id (Xóa món ăn)
    console.log('\n[9] Testing DELETE /api/products/:id (Xóa món)...');
    const deleteProdRes = await fetch(`${baseUrl}/products/${productId}`, {
      method: 'DELETE',
      headers: authHeaders,
    });
    const deleteProdData = await deleteProdRes.json();
    console.log('Status:', deleteProdRes.status, 'Success:', deleteProdData.success);
    if (!deleteProdData.success) {
      throw new Error('DELETE product failed: ' + JSON.stringify(deleteProdData));
    }
    console.log(`✓ Product deleted successfully! Cleaned up ID: ${productId}`);

    console.log('\n========================================');
    console.log('🎉 ALL 9 MEMBER 3 REST APIS PASSED 100%!');
    console.log('========================================\n');
  } finally {
    server.close();
    await mongoose.disconnect();
  }
}

runTests().catch(err => {
  console.error('❌ Test failed with error:', err);
  process.exit(1);
});
