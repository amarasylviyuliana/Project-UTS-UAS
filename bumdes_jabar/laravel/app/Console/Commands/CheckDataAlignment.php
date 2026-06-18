<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use App\Models\User;
use App\Models\Store;
use App\Models\Product;
use App\Models\Admin;
use App\Models\StoreApproval;
use App\Models\ProductApproval;
use App\Models\SellerVerification;

class CheckDataAlignment extends Command
{
    /**
     * The name and signature of the console command.
     *
     * @var string
     */
    protected $signature = 'data:check-alignment {--fix : Automatically fix issues}';

    /**
     * The console command description.
     *
     * @var string
     */
    protected $description = 'Check data alignment between User, Seller, and Admin';

    /**
     * Execute the console command.
     */
    public function handle()
    {
        $this->line('🔍 Checking data alignment...');
        $this->newLine();

        $issues = [];

        // 1. Check Admin users without Admin model
        $this->line('1️⃣  Checking Admin users without Admin profile...');
        $adminUsersWithoutProfile = User::where('role', 'Admin')
            ->whereDoesntHave('admin')
            ->get();

        if ($adminUsersWithoutProfile->count() > 0) {
            $this->warn("⚠️  Found {$adminUsersWithoutProfile->count()} admin users without profile");
            $issues[] = ['issue' => 'Admin users without profile', 'count' => $adminUsersWithoutProfile->count()];

            if ($this->option('fix')) {
                foreach ($adminUsersWithoutProfile as $user) {
                    Admin::create([
                        'user_id' => $user->id,
                        'department' => 'Unassigned',
                        'job_title' => 'Unassigned',
                        'is_super_admin' => false,
                        'is_active' => true,
                    ]);
                }
                $this->info("✅ Created {$adminUsersWithoutProfile->count()} admin profiles");
            }
        } else {
            $this->info('✅ All admin users have profiles');
        }
        $this->newLine();

        // 2. Check Seller users without Store
        $this->line('2️⃣  Checking seller users without store...');
        $sellerUsersWithoutStore = User::where('role', 'Penjual')
            ->whereDoesntHave('store')
            ->get();

        if ($sellerUsersWithoutStore->count() > 0) {
            $this->warn("⚠️  Found {$sellerUsersWithoutStore->count()} sellers without store");
            $issues[] = ['issue' => 'Sellers without store', 'count' => $sellerUsersWithoutStore->count()];
        } else {
            $this->info('✅ All sellers have stores');
        }
        $this->newLine();

        // 3. Check Stores without approval record
        $this->line('3️⃣  Checking stores without approval record...');
        $storesWithoutApproval = Store::whereDoesntHave('storeApproval')->get();

        if ($storesWithoutApproval->count() > 0) {
            $this->warn("⚠️  Found {$storesWithoutApproval->count()} stores without approval record");
            $issues[] = ['issue' => 'Stores without approval', 'count' => $storesWithoutApproval->count()];

            if ($this->option('fix')) {
                foreach ($storesWithoutApproval as $store) {
                    // Find or create default admin
                    $admin = Admin::where('is_super_admin', true)->first();
                    if (!$admin) {
                        $admin = Admin::first();
                    }

                    if ($admin) {
                        StoreApproval::create([
                            'store_id' => $store->id,
                            'admin_id' => $admin->id,
                            'status' => $store->is_active ? 'Disetujui' : 'Menunggu Persetujuan',
                            'approved_at' => $store->is_active ? now() : null,
                        ]);
                    }
                }
                $this->info("✅ Created {$storesWithoutApproval->count()} approval records");
            }
        } else {
            $this->info('✅ All stores have approval records');
        }
        $this->newLine();

        // 4. Check Sellers without verification record
        $this->line('4️⃣  Checking sellers without verification record...');
        $sellersWithoutVerif = User::where('role', 'Penjual')
            ->whereDoesntHave('sellerVerification')
            ->get();

        if ($sellersWithoutVerif->count() > 0) {
            $this->warn("⚠️  Found {$sellersWithoutVerif->count()} sellers without verification record");
            $issues[] = ['issue' => 'Sellers without verification', 'count' => $sellersWithoutVerif->count()];

            if ($this->option('fix')) {
                foreach ($sellersWithoutVerif as $user) {
                    if ($user->store) {
                        SellerVerification::create([
                            'user_id' => $user->id,
                            'store_id' => $user->store->id,
                            'status' => 'Menunggu Verifikasi',
                        ]);
                    }
                }
                $this->info("✅ Created {$sellersWithoutVerif->count()} verification records");
            }
        } else {
            $this->info('✅ All sellers have verification records');
        }
        $this->newLine();

        // 5. Check Products without approval record
        $this->line('5️⃣  Checking products without approval record...');
        $productsWithoutApproval = Product::whereDoesntHave('productApproval')->get();

        if ($productsWithoutApproval->count() > 0) {
            $this->warn("⚠️  Found {$productsWithoutApproval->count()} products without approval record");
            $issues[] = ['issue' => 'Products without approval', 'count' => $productsWithoutApproval->count()];

            if ($this->option('fix')) {
                foreach ($productsWithoutApproval as $product) {
                    $admin = Admin::where('is_super_admin', true)->first();
                    if (!$admin) {
                        $admin = Admin::first();
                    }

                    if ($admin) {
                        ProductApproval::create([
                            'product_id' => $product->id,
                            'admin_id' => $admin->id,
                            'status' => $product->is_active ? 'Disetujui' : 'Menunggu Persetujuan',
                            'approved_at' => $product->is_active ? now() : null,
                        ]);
                    }
                }
                $this->info("✅ Created {$productsWithoutApproval->count()} approval records");
            }
        } else {
            $this->info('✅ All products have approval records');
        }
        $this->newLine();

        // 6. Check orphaned approvals
        $this->line('6️⃣  Checking orphaned approval records...');
        $orphanedStoreApprovals = StoreApproval::whereDoesntHave('store')->count();
        $orphanedProductApprovals = ProductApproval::whereDoesntHave('product')->count();
        $orphanedVerifications = SellerVerification::whereDoesntHave('store')->count();

        if ($orphanedStoreApprovals > 0 || $orphanedProductApprovals > 0 || $orphanedVerifications > 0) {
            $this->warn("⚠️  Found orphaned records");
            if ($orphanedStoreApprovals > 0) {
                $this->warn("   - $orphanedStoreApprovals orphaned store approvals");
                $issues[] = ['issue' => 'Orphaned store approvals', 'count' => $orphanedStoreApprovals];
            }
            if ($orphanedProductApprovals > 0) {
                $this->warn("   - $orphanedProductApprovals orphaned product approvals");
                $issues[] = ['issue' => 'Orphaned product approvals', 'count' => $orphanedProductApprovals];
            }
            if ($orphanedVerifications > 0) {
                $this->warn("   - $orphanedVerifications orphaned verifications");
                $issues[] = ['issue' => 'Orphaned verifications', 'count' => $orphanedVerifications];
            }
        } else {
            $this->info('✅ No orphaned records found');
        }
        $this->newLine();

        // 7. Summary
        $this->line('📊 Summary:');
        $this->info('✅ Total users: ' . User::count());
        $this->info('✅ Total admins: ' . Admin::count());
        $this->info('✅ Total sellers: ' . User::where('role', 'Penjual')->count());
        $this->info('✅ Total stores: ' . Store::count());
        $this->info('✅ Total verified sellers: ' . SellerVerification::where('status', 'Terverifikasi')->count());
        $this->info('✅ Total approved stores: ' . StoreApproval::where('status', 'Disetujui')->count());
        $this->info('✅ Total products: ' . Product::count());
        $this->info('✅ Total approved products: ' . ProductApproval::where('status', 'Disetujui')->count());
        $this->newLine();

        if (count($issues) === 0) {
            $this->info('🎉 All data is properly aligned!');
            return 0;
        } else {
            $this->warn('⚠️  ' . count($issues) . ' alignment issue(s) found');
            if (!$this->option('fix')) {
                $this->info('💡 Run with --fix flag to automatically fix issues: php artisan data:check-alignment --fix');
            }
            return 1;
        }
    }
}
