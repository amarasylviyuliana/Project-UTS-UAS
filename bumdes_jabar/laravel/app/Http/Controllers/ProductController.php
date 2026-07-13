public function store(Request $request): JsonResponse
    {
        $user = $request->user();

        if (! $user->isSeller()) {
            return response()->json([
                'message' => 'Hanya penjual yang dapat menambahkan produk',
            ], 403);
        }

        $store = $user->store;
        if (!$store) {
            return response()->json([
                'message' => 'Anda harus mendaftarkan toko terlebih dahulu',
            ], 403);
        }

        if (!$store->is_active) {
            return response()->json([
                'message' => 'Toko Anda belum disetujui admin. Mohon tunggu persetujuan sebelum menambahkan produk.',
            ], 403);
        }

        $validated = $request->validate([
            'name' => 'required|string|max:255',
            'category_id' => 'required|exists:categories,id',
            'type' => 'required|in:produk,jasa',
            'price' => 'required|numeric|min:0',
            'stock' => 'required_if:type,produk|numeric|min:0',
            'description' => 'sometimes|string',
            'photo' => 'sometimes|image|mimes:jpeg,png,jpg|max:5120',
            'image_url' => 'sometimes|nullable|string',
            // TAMBAHAN: seller boleh set status aktif produk/jasa saat
            // membuat. Dipakai untuk toggle Tersedia/Tidak Tersedia pada
            // Jasa. Kalau tidak dikirim, default aktif (true).
            'is_active' => 'sometimes|boolean',
        ]);

        $photoUrl = null;
        if ($request->hasFile('photo')) {
            $photoUrl = $request->file('photo')->store('product-photos', 'public');
        } elseif (!empty($validated['image_url'] ?? null)) {
            $photoUrl = $validated['image_url'];
        }

        $product = $store->products()->create([
            'name' => $validated['name'],
            'category_id' => $validated['category_id'],
            'type' => $validated['type'],
            'price' => $validated['price'],
            'stock' => $validated['stock'] ?? 0,
            'description' => $validated['description'] ?? null,
            'photo_url' => $photoUrl,
            'is_active' => $validated['is_active'] ?? true,
        ]);

        $product->load(['store.user', 'category']);

        return response()->json([
            'message' => 'Produk berhasil ditambahkan',
            'data' => $this->mapProductForResponse($product),
        ], 201);
    }

    public function update(Request $request, $id): JsonResponse
    {
        $user = $request->user();

        if (! $user->isSeller()) {
            return response()->json([
                'message' => 'Hanya penjual yang dapat mengubah produk',
            ], 403);
        }

        $product = Product::find($id);

        $storeOwnerId = $product && $product->store ? $product->store->user_id : null;
        Log::debug('Product update permission check', [
            'user_id' => $user->id,
            'user_role' => $user->role,
            'product_id' => $id,
            'product_exists' => $product !== null,
            'product_store_id' => $product?->store?->id,
            'product_store_owner_id' => $storeOwnerId,
            'request_payload' => $request->all(),
        ]);

        if (!$product || $storeOwnerId !== $user->id) {
            return response()->json([
                'message' => 'Produk tidak ditemukan atau anda tidak punya akses',
            ], 404);
        }

        $validated = $request->validate([
            'name' => 'sometimes|string|max:255',
            'category_id' => 'sometimes|exists:categories,id',
            'type' => 'sometimes|in:produk,jasa',
            'price' => 'sometimes|numeric|min:0',
            'stock' => 'sometimes|numeric|min:0',
            'description' => 'sometimes|string',
            'photo' => 'sometimes|image|mimes:jpeg,png,jpg|max:5120',
            'image_url' => 'sometimes|nullable|string',
            // TAMBAHAN: sebelumnya seller HANYA bisa nonaktifkan produk
            // lewat endpoint /deactivate (khusus admin). Sekarang seller
            // bisa toggle is_active sendiri lewat form edit — dipakai
            // untuk toggle Tersedia/Tidak Tersedia pada Jasa.
            'is_active' => 'sometimes|boolean',
        ]);

        $photoUrl = $product->photo_url;
        if ($request->hasFile('photo')) {
            $photoUrl = $request->file('photo')->store('product-photos', 'public');
        } elseif (!empty($validated['image_url'] ?? null)) {
            $photoUrl = $validated['image_url'];
        }

        unset($validated['image_url']);
        $validated['photo_url'] = $photoUrl;

        // Kalau field is_active tidak dikirim (mis. request lama / klien
        // belum update), pertahankan status aktif yang sudah ada supaya
        // tidak diam-diam mengubahnya jadi default true.
        if (!array_key_exists('is_active', $validated)) {
            $validated['is_active'] = $product->is_active;
        }

        $product->update($validated);

        $product->load(['store.user', 'category']);

        return response()->json([
            'message' => 'Produk berhasil diperbarui',
            'data' => $this->mapProductForResponse($product),
        ]);
    }