package pt.rjp.cleaner

import android.Manifest
import android.app.AlertDialog
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.provider.Settings
import android.text.format.Formatter
import android.view.Gravity
import android.view.View
import android.widget.*
import androidx.appcompat.app.AppCompatActivity
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import java.io.File
import java.security.MessageDigest
import java.util.concurrent.Executors

class MainActivity : AppCompatActivity() {
    private val executor = Executors.newSingleThreadExecutor()
    private lateinit var status: TextView
    private lateinit var results: LinearLayout
    private lateinit var progress: ProgressBar
    private val candidates = mutableListOf<File>()
    private var autoScanDone = false
    private val prefs by lazy { getSharedPreferences("rjp_cleaner", MODE_PRIVATE) }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(buildUi())
        ensurePermissions()
        showStorageSummary()
    }

    override fun onResume() {
        super.onResume()
        if (!autoScanDone && prefs.getBoolean("auto_scan", true) && hasStorageAccess()) {
            autoScanDone = true
            window.decorView.postDelayed({ scanRecommended() }, 500)
        }
    }

    private fun buildUi(): View {
        val scroll = ScrollView(this)
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(28, 24, 28, 48)
            setBackgroundColor(0xFFF5F7FA.toInt())
        }
        root.addView(TextView(this).apply {
            text = "RJP Cleaner"; textSize = 30f; setTextColor(0xFF08284A.toInt()); setTypeface(typeface, 1)
        })
        root.addView(TextView(this).apply {
            text = "Espaço limpo. Telemóvel leve."; textSize = 15f; setPadding(0, 4, 0, 18)
        })
        status = TextView(this).apply { textSize = 16f; setPadding(0, 8, 0, 12) }
        root.addView(status)
        progress = ProgressBar(this).apply { visibility = View.GONE }
        root.addView(progress)

        root.addView(button("✨ LIMPEZA RECOMENDADA") { scanRecommended() })
        root.addView(button("🖼️ FOTOS E VÍDEOS") { scanMedia() })
        root.addView(button("📥 DOWNLOADS") { scanDir(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS), "Downloads") })
        root.addView(button("💬 WHATSAPP / MEDIA") { scanWhatsApp() })
        root.addView(button("📦 FICHEIROS GRANDES > 500 MB") { scanLargeFiles() })
        root.addView(button("📱 APKs ANTIGOS") { scanApks() })
        root.addView(button("🟰 DUPLICADOS") { scanDuplicates() })
        root.addView(button("⚙️ GESTÃO AUTOMÁTICA") { showAutomationSettings() })
        root.addView(button("🗑️ LIMPAR SELECIONADOS") { confirmDelete() })

        root.addView(TextView(this).apply { text = "Resultados"; textSize = 21f; setTypeface(typeface, 1); setPadding(0, 24, 0, 10) })
        results = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL }
        root.addView(results)
        scroll.addView(root)
        return scroll
    }

    private fun button(label: String, action: () -> Unit) = Button(this).apply {
        text = label; isAllCaps = false; textSize = 16f; setOnClickListener { action() }
        val lp = LinearLayout.LayoutParams(-1, -2); lp.setMargins(0, 5, 0, 5); layoutParams = lp
    }

    private fun hasStorageAccess(): Boolean = if (Build.VERSION.SDK_INT >= 30) Environment.isExternalStorageManager() else true

    private fun ensurePermissions() {
        if (Build.VERSION.SDK_INT >= 30 && !Environment.isExternalStorageManager()) {
            AlertDialog.Builder(this).setTitle("Permissão de armazenamento")
                .setMessage("Para analisar Downloads, WhatsApp, APKs e outros ficheiros partilhados, ativa 'Permitir gestão de todos os ficheiros' para o RJP Cleaner.")
                .setPositiveButton("Abrir definições") { _, _ ->
                    try { startActivity(Intent(Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION, Uri.parse("package:$packageName"))) }
                    catch (_: Exception) { startActivity(Intent(Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION)) }
                }.setNegativeButton("Mais tarde", null).show()
        }
        if (Build.VERSION.SDK_INT >= 33) {
            val perms = arrayOf(Manifest.permission.READ_MEDIA_IMAGES, Manifest.permission.READ_MEDIA_VIDEO, Manifest.permission.READ_MEDIA_AUDIO)
            val missing = perms.filter { ContextCompat.checkSelfPermission(this, it) != PackageManager.PERMISSION_GRANTED }
            if (missing.isNotEmpty()) ActivityCompat.requestPermissions(this, missing.toTypedArray(), 33)
        }
    }

    private fun showStorageSummary() {
        val root = Environment.getExternalStorageDirectory(); val total = root.totalSpace; val free = root.freeSpace
        status.text = "${Formatter.formatFileSize(this, total-free)} usados de ${Formatter.formatFileSize(this,total)} • ${Formatter.formatFileSize(this,free)} livres"
    }

    private fun scanRecommended() = backgroundScan("A fazer triagem automática…", visual = true, preselect = true) {
        collectFiles(Environment.getExternalStorageDirectory()).filter { isRecommended(it) }.sortedByDescending { it.length() }
    }

    private fun scanMedia() = backgroundScan("A analisar fotos e vídeos…", visual = true) {
        val roots = listOf(
            Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DCIM),
            Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES),
            Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_MOVIES)
        )
        roots.flatMap { collectFiles(it) }.filter { isMedia(it) }.distinctBy { it.absolutePath }.sortedByDescending { it.length() }
    }

    private fun scanDir(dir: File, title: String) = backgroundScan("A analisar $title…") { collectFiles(dir).sortedByDescending { it.length() } }

    private fun scanWhatsApp() = backgroundScan("A analisar WhatsApp…", visual = true) {
        val root = Environment.getExternalStorageDirectory()
        val dirs = listOf(File(root, "Android/media/com.whatsapp/WhatsApp/Media"), File(root, "WhatsApp/Media"), File(root, "Android/media/com.whatsapp.w4b/WhatsApp Business/Media"))
        dirs.filter { it.exists() }.flatMap { collectFiles(it) }.sortedByDescending { it.length() }
    }

    private fun scanLargeFiles() = backgroundScan("A procurar ficheiros grandes…") { collectFiles(Environment.getExternalStorageDirectory()).filter { it.length() >= 500L*1024*1024 }.sortedByDescending { it.length() } }
    private fun scanApks() = backgroundScan("A procurar APKs…") { collectFiles(Environment.getExternalStorageDirectory()).filter { it.extension.equals("apk", true) }.sortedByDescending { it.lastModified() } }

    private fun scanDuplicates() = backgroundScan("A calcular duplicados…", visual = true) {
        val files = collectFiles(Environment.getExternalStorageDirectory()).filter { it.length() > 0 && it.length() < 1024L*1024*1024 }
        val dups = mutableListOf<File>()
        files.groupBy { it.length() }.filterValues { it.size > 1 }.values.forEach { group ->
            group.groupBy { sha256(it) }.values.filter { it.size > 1 }.forEach { same -> dups.addAll(same.drop(1)) }
        }
        dups.sortedByDescending { it.length() }
    }

    private fun isRecommended(f: File): Boolean {
        val ageDays = (System.currentTimeMillis() - f.lastModified()) / 86_400_000L
        val largeMediaMB = prefs.getInt("large_media_mb", 300)
        val oldDays = prefs.getInt("old_days", 180)
        val n = f.name.lowercase()
        val oldDownload = ageDays >= oldDays && f.absolutePath.contains("/Download", true)
        val oldScreenshot = ageDays >= 30 && (n.contains("screenshot") || n.contains("captura"))
        val largeMedia = isMedia(f) && f.length() >= largeMediaMB.toLong()*1024*1024
        val installer = n.endsWith(".apk") || n.endsWith(".zip")
        return oldDownload || oldScreenshot || largeMedia || installer
    }

    private fun isMedia(f: File): Boolean {
        val e = f.extension.lowercase()
        return e in setOf("jpg","jpeg","png","webp","heic","heif","gif","mp4","mkv","mov","3gp","webm","avi")
    }
    private fun isVideo(f: File): Boolean = f.extension.lowercase() in setOf("mp4","mkv","mov","3gp","webm","avi")

    private fun collectFiles(start: File): List<File> {
        val out = mutableListOf<File>(); val stack = ArrayDeque<File>(); if (start.exists()) stack.add(start)
        while (stack.isNotEmpty()) {
            val f = stack.removeLast()
            try { if (f.isDirectory) f.listFiles()?.forEach { child ->
                if (child.isDirectory) { val p = child.absolutePath; if (!p.contains("/Android/data/") && !p.contains("/Android/obb/")) stack.add(child) } else out.add(child)
            } } catch (_: Exception) {}
        }
        return out
    }

    private fun sha256(file: File): String = try {
        val md = MessageDigest.getInstance("SHA-256"); file.inputStream().use { input ->
            val b = ByteArray(1024*1024); var n: Int; while (input.read(b).also { n=it } > 0) md.update(b,0,n)
        }; md.digest().joinToString("") { "%02x".format(it) }
    } catch (_: Exception) { file.absolutePath }

    private fun backgroundScan(message: String, visual: Boolean = false, preselect: Boolean = false, block: () -> List<File>) {
        progress.visibility = View.VISIBLE; status.text = message; results.removeAllViews(); candidates.clear()
        executor.execute {
            val data = try { block() } catch (_: Exception) { emptyList() }
            runOnUiThread {
                progress.visibility = View.GONE; candidates.addAll(data.take(500)); val total = candidates.sumOf { it.length() }
                status.text = "${candidates.size} itens • ${Formatter.formatFileSize(this,total)} potencialmente geríveis"
                renderResults(visual, preselect)
            }
        }
    }

    private fun renderResults(visual: Boolean = false, preselect: Boolean = false) {
        results.removeAllViews()
        if (candidates.isEmpty()) { results.addView(TextView(this).apply { text="Nada encontrado nesta análise." }); return }
        candidates.forEach { f -> results.addView(if (visual && isMedia(f)) mediaRow(f, preselect) else fileCheck(f, preselect)) }
    }

    private fun fileCheck(f: File, checked: Boolean): CheckBox = CheckBox(this).apply {
        tag=f; isChecked=checked; text="${f.name}\n${Formatter.formatFileSize(this@MainActivity,f.length())}  •  ${f.parent ?: ""}"; setPadding(0,8,0,8)
    }

    private fun mediaRow(f: File, checked: Boolean): View {
        val row = LinearLayout(this).apply { orientation=LinearLayout.HORIZONTAL; gravity=Gravity.CENTER_VERTICAL; setPadding(0,8,0,8) }
        val image = ImageView(this).apply { layoutParams=LinearLayout.LayoutParams(180,180); scaleType=ImageView.ScaleType.CENTER_CROP; setImageResource(android.R.drawable.ic_menu_gallery) }
        row.addView(image)
        val cb = CheckBox(this).apply {
            tag=f; isChecked=checked; text="${if (isVideo(f)) "▶ " else ""}${f.name}\n${Formatter.formatFileSize(this@MainActivity,f.length())}"; setPadding(12,0,0,0)
            layoutParams=LinearLayout.LayoutParams(0,-2,1f)
        }
        row.addView(cb)
        executor.execute { val bmp = createThumbnail(f); if (bmp != null) runOnUiThread { image.setImageBitmap(bmp) } }
        return row
    }

    private fun createThumbnail(file: File): Bitmap? = try {
        if (isVideo(file)) {
            val r=MediaMetadataRetriever(); r.setDataSource(file.absolutePath); val b=r.getFrameAtTime(0, MediaMetadataRetriever.OPTION_CLOSEST_SYNC); r.release(); b
        } else {
            val opts=BitmapFactory.Options().apply { inJustDecodeBounds=true }; BitmapFactory.decodeFile(file.absolutePath,opts)
            var sample=1; while (opts.outWidth/sample > 320 || opts.outHeight/sample > 320) sample*=2
            BitmapFactory.decodeFile(file.absolutePath, BitmapFactory.Options().apply { inSampleSize=sample })
        }
    } catch (_:Exception) { null }

    private fun selectedFiles(): List<File> {
        val out=mutableListOf<File>()
        fun walk(v: View) {
            if (v is CheckBox && v.isChecked) (v.tag as? File)?.let(out::add)
            if (v is LinearLayout) for (i in 0 until v.childCount) walk(v.getChildAt(i))
        }
        walk(results); return out.distinctBy { it.absolutePath }
    }

    private fun confirmDelete() {
        val selected=selectedFiles(); if (selected.isEmpty()) { Toast.makeText(this,"Seleciona primeiro os ficheiros a eliminar.",Toast.LENGTH_SHORT).show(); return }
        val size=selected.sumOf { it.length() }
        AlertDialog.Builder(this).setTitle("Eliminar ficheiros?").setMessage("Selecionaste ${selected.size} itens (${Formatter.formatFileSize(this,size)}). Confirma a limpeza.")
            .setPositiveButton("Eliminar") { _, _ -> deleteSelected(selected) }.setNegativeButton("Cancelar",null).show()
    }

    private fun deleteSelected(files: List<File>) {
        var ok=0; files.forEach { try { if (it.delete()) ok++ } catch (_:Exception) {} }
        Toast.makeText(this,"$ok de ${files.size} ficheiros eliminados.",Toast.LENGTH_LONG).show(); candidates.removeAll(files.toSet()); renderResults(); showStorageSummary()
    }

    private fun showAutomationSettings() {
        val box=LinearLayout(this).apply { orientation=LinearLayout.VERTICAL; setPadding(48,16,48,0) }
        val auto=CheckBox(this).apply { text="Analisar automaticamente ao abrir"; isChecked=prefs.getBoolean("auto_scan",true) }
        val media=EditText(this).apply { hint="Vídeo/foto grande (MB)"; inputType=2; setText(prefs.getInt("large_media_mb",300).toString()) }
        val days=EditText(this).apply { hint="Antiguidade (dias)"; inputType=2; setText(prefs.getInt("old_days",180).toString()) }
        box.addView(auto); box.addView(media); box.addView(days)
        AlertDialog.Builder(this).setTitle("Gestão automática").setView(box)
            .setMessage("A app faz a triagem automaticamente, mas nunca apaga fotos, vídeos ou documentos sem confirmação.")
            .setPositiveButton("Guardar") { _, _ -> prefs.edit().putBoolean("auto_scan",auto.isChecked).putInt("large_media_mb",media.text.toString().toIntOrNull() ?: 300).putInt("old_days",days.text.toString().toIntOrNull() ?: 180).apply() }
            .setNegativeButton("Cancelar",null).show()
    }
}
