-- ============================================================
-- ANALISIS E-COMMERCE INDONESIA 2023-2025
-- Dataset: 23 file Excel Shopee, 22.933 baris (cleaned)
-- Periode: Desember 2023 - November 2025 (24 bulan)
-- Database: PostgreSQL 18 | Tabel: sales_data
-- ============================================================


-- ============================================================
-- BAGIAN 1: EKSPLORASI DATA
-- ============================================================

-- Q1: Total record di dataset
SELECT COUNT(*) AS total_records
FROM sales_data;
-- Hasil: 22.933 baris


-- Q2: Periode data
SELECT 
    MIN(waktu_pesanan_dibuat) AS tanggal_paling_awal,
    MAX(waktu_pesanan_dibuat) AS tanggal_paling_akhir
FROM sales_data;
-- Hasil: 2023-12-01 sampai 2025-11-30 (24 bulan)


-- Q3: Jumlah unique product category
SELECT COUNT(DISTINCT product_category) AS jumlah_kategori
FROM sales_data;
-- Hasil: 38 kategori


-- Q4: Top 10 kategori produk by transaksi
SELECT 
    product_category,
    COUNT(*) AS jumlah_transaksi
FROM sales_data
GROUP BY product_category
ORDER BY jumlah_transaksi DESC
LIMIT 10;
-- Insight: Celengan dominan (5811 trx), Top 3 = 55% total transaksi
-- Bisnis: peralatan rumah tangga & DIY


-- ============================================================
-- BAGIAN 2: KPI UTAMA
-- ============================================================

-- Q5: KPI Utama - Total Orders, Revenue, AOV (Selesai only)
SELECT 
    COUNT(DISTINCT order_id) AS total_orders,
    SUM(total_pembayaran) AS total_revenue,
    ROUND(SUM(total_pembayaran)::numeric / COUNT(DISTINCT order_id), 0) AS avg_order_value
FROM (
    SELECT DISTINCT order_id, total_pembayaran
    FROM sales_data
    WHERE status_pesanan = 'Selesai'
) AS unique_orders;
-- Hasil: 17.768 orders | Rp 1.045.550.734 | AOV Rp 58.845


-- ============================================================
-- BAGIAN 3: STATUS PESANAN & CANCELLATION
-- ============================================================

-- Q6: Status pesanan disederhanakan
SELECT 
    CASE 
        WHEN status_pesanan = 'Selesai' THEN 'Selesai'
        WHEN status_pesanan = 'Batal' THEN 'Batal'
        WHEN status_pesanan IN ('Sedang Dikirim', 'Telah Dikirim') THEN 'Dalam Pengiriman'
        WHEN status_pesanan LIKE 'Pesanan diterima%' THEN 'Periode Pengembalian'
        ELSE 'Lainnya'
    END AS status_kategori,
    COUNT(DISTINCT order_id) AS jumlah_order,
    ROUND(
        COUNT(DISTINCT order_id) * 100.0 / SUM(COUNT(DISTINCT order_id)) OVER (),
        2
    ) AS persentase
FROM sales_data
GROUP BY status_kategori
ORDER BY jumlah_order DESC;
-- Hasil:
-- Selesai: 17.768 (86.21%) | Batal: 2.593 (12.58%)
-- Periode Pengembalian: 161 (0.78%) | Dalam Pengiriman: 89 (0.43%)


-- Q7: Top 10 alasan pembatalan
SELECT 
    alasan_pembatalan,
    COUNT(DISTINCT order_id) AS jumlah_order,
    ROUND(
        COUNT(DISTINCT order_id) * 100.0 / SUM(COUNT(DISTINCT order_id)) OVER (),
        2
    ) AS persentase
FROM sales_data
WHERE status_pesanan = 'Batal'
GROUP BY alasan_pembatalan
ORDER BY jumlah_order DESC
LIMIT 10;
-- Insight: 60% buyer behavior (change mind, ubah alamat)
--         15% payment timeout
--         16% operational (penjual/sistem)


-- ============================================================
-- BAGIAN 4: TREND & TIME SERIES
-- ============================================================

-- Q8: Trend Revenue & Orders per Bulan
SELECT 
    TO_CHAR(waktu_pesanan_dibuat, 'YYYY-MM') AS bulan,
    COUNT(DISTINCT order_id) AS total_orders,
    SUM(total_pembayaran) AS total_revenue
FROM (
    SELECT DISTINCT order_id, waktu_pesanan_dibuat, total_pembayaran, status_pesanan
    FROM sales_data
) AS unique_orders
WHERE status_pesanan = 'Selesai'
GROUP BY bulan
ORDER BY bulan;
-- Insight: Peak Juli 2024 (Rp 71.2jt), Dip Maret 2025 (Rp 43.7jt)


-- Q9: YoY Growth Analysis
SELECT 
    EXTRACT(YEAR FROM waktu_pesanan_dibuat) AS tahun,
    COUNT(DISTINCT order_id) AS total_orders,
    SUM(total_pembayaran) AS total_revenue,
    ROUND(AVG(total_pembayaran)::numeric, 0) AS avg_order_value
FROM (
    SELECT DISTINCT order_id, waktu_pesanan_dibuat, total_pembayaran, status_pesanan
    FROM sales_data
) AS unique_orders
WHERE status_pesanan = 'Selesai'
GROUP BY tahun
ORDER BY tahun;
-- Insight: Volume MoM +7%, tapi AOV -11% (Rp 62K -> Rp 55K)
-- Red flag: revenue quality menurun, kemungkinan promo agresif


-- Q10: Peak Hours Analysis
SELECT 
    EXTRACT(HOUR FROM waktu_pesanan_dibuat) AS jam,
    COUNT(DISTINCT order_id) AS total_orders,
    SUM(total_pembayaran) AS total_revenue
FROM (
    SELECT DISTINCT order_id, waktu_pesanan_dibuat, total_pembayaran, status_pesanan
    FROM sales_data
) AS unique_orders
WHERE status_pesanan = 'Selesai'
GROUP BY jam
ORDER BY jam;
-- Insight: Peak 18:00-20:00 (golden hours)
--         Anomaly jam 00:00 (325 orders, kemungkinan flash sale)
--         Dead zone 02:00-04:00


-- ============================================================
-- BAGIAN 5: GEOGRAPHIC ANALYSIS
-- ============================================================

-- Q11: Top 10 Provinsi by Revenue
SELECT 
    provinsi,
    COUNT(DISTINCT order_id) AS total_orders,
    SUM(total_pembayaran) AS total_revenue,
    ROUND(AVG(total_pembayaran)::numeric, 0) AS avg_order_value
FROM (
    SELECT DISTINCT order_id, provinsi, total_pembayaran, status_pesanan
    FROM sales_data
) AS unique_orders
WHERE status_pesanan = 'Selesai'
GROUP BY provinsi
ORDER BY total_revenue DESC
LIMIT 10;
-- Insight: Jabar dominan (Rp 275jt, 26%)
--         Bali outlier: low volume, AOV 2.9x rata-rata (potensi B2B)
--         Java = 65% revenue


-- ============================================================
-- BAGIAN 6: PAYMENT BEHAVIOR
-- ============================================================

-- Q12: Distribusi Metode Pembayaran
SELECT 
    metode_pembayaran,
    COUNT(DISTINCT order_id) AS total_orders,
    SUM(total_pembayaran) AS total_revenue,
    ROUND(
        COUNT(DISTINCT order_id) * 100.0 / SUM(COUNT(DISTINCT order_id)) OVER (),
        2
    ) AS persentase_order
FROM (
    SELECT DISTINCT order_id, metode_pembayaran, total_pembayaran, status_pesanan
    FROM sales_data
) AS unique_orders
WHERE status_pesanan = 'Selesai'
GROUP BY metode_pembayaran
ORDER BY total_orders DESC;
-- Insight: COD dominan (55%), Shopee internal (ShopeePay+SPayLater) 26%
--         AOV tertinggi di minimarket payment (Rp 200K+)


-- ============================================================
-- BAGIAN 7: SHIPPING & OPERATIONS
-- ============================================================

-- Q13: Analisis Subsidi Shipping per Provinsi
SELECT 
    provinsi,
    COUNT(DISTINCT order_id) AS total_orders,
    SUM(ongkos_kirim_dibayar_oleh_pembeli) AS total_ongkir_dibayar,
    SUM(estimasi_potongan_biaya_pengiriman) AS total_subsidi,
    SUM(perkiraan_ongkos_kirim) AS perkiraan_ongkir_sebenarnya,
    ROUND(
        (SUM(estimasi_potongan_biaya_pengiriman) / 
        NULLIF(SUM(perkiraan_ongkos_kirim), 0) * 100)::numeric, 
        2
    ) AS persentase_subsidi
FROM (
    SELECT DISTINCT 
        order_id, 
        provinsi, 
        ongkos_kirim_dibayar_oleh_pembeli,
        estimasi_potongan_biaya_pengiriman,
        perkiraan_ongkos_kirim,
        status_pesanan
    FROM sales_data
) AS unique_orders
WHERE status_pesanan = 'Selesai'
GROUP BY provinsi
ORDER BY total_subsidi DESC
LIMIT 10;
-- Insight: Shopee subsidi 70-80% ongkir
--         Subsidi tertinggi di luar Java (Jambi 79.82%, Lampung 78.70%)
--         Profitability concern: ongkir 30% dari nilai produk