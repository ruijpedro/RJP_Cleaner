package pt.rjp.cleaner

import android.Manifest
import android.app.AlertDialog
import android.content.Intent
import android.content.pm.PackageManager
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

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(buildUi())
        ensurePermissions()
        showStorageSummary()
    }

    private fun buildUi(): View {
        val scroll = ScrollView(this)
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(36, 28, 36, 48)
            setBackgroundColor(0xFFF5F7FA.toInt())
        }
        root.addView(TextView(this).apply {
            text = "RJP Cleaner"
            textSize = 30f
            setTextColor(0xFF08284A.toInt())
            setTypeface(typeface, 1)
        })
        root.addView(TextView(this).apply {
            text = "Espaço limpo. Telemóvel leve."
            textSize = 15f
            setPadding(0, 4, 0, 24)
        })
        status = TextView(this).apply { textSize = 17f; setPadding(0, 8, 0, 12) }
        root.addView(status)
        progress = ProgressBar(this).apply { visibility = View.GONE }
        root.addView(progress)

        root.addView(button("ANALISAR TELEMÓVEL") { scanAll() })
        root.addView(button("DOWNLOADS") { scanDir(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS), "Downloads") })
        root.addView(button("WHATSAPP / MEDIA") { scanWhatsApp() })
        root.addView(button("FICHEIROS GRANDES > 500 MB") { scanLargeFiles() })
        root.addView(button("APKs ANTIGOS") { scanApks() })
        root.addView(button("DUPLICADOS") { scanDuplicates() })
        root.addView(button("LIMPAR SELECIONADOS") { confirmDelete() })

        root.addView(TextView(this).apply {
            text = "Resultados"
            textSize = 21f
            setTypeface(typeface, 1)
            setPadding(0, 28, 0, 10)
        })
        results = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL }
        root.addView(results)
        scroll.addView(root)
        return scroll
    }

    private fun button(label: String, action: () -> Unit) = Button(this).apply {
        text = label
        isAllCaps = false
        textSize = 16f
        setOnClickListener { action() }
        val lp = LinearLayout.LayoutParams(-1, -2); lp.setMargins(0, 6, 0, 6); layoutParams = lp
    }

    private fun ensurePermissions() {
        if (Build.VERSION.SDK_INT >= 30 && !Environment.isExternalStorageManager()) {
            AlertDialog.Builder(this)
                .setTitle("Permissão de armazenamento")
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
        val root = Environment.getExternalStorageDirectory()
        val total = root.totalSpace
        val free = root.freeSpace
        status.text = "Armazenamento: ${Formatter.formatFileSize(this, total-free)} usados de ${Formatter.formatFileSize(this,total)} • ${Formatter.formatFileSize(this,free)} livres"
    }

    private fun scanAll() = backgroundScan("A analisar armazenamento…") {
        collectFiles(Environment.getExternalStorageDirectory()).filter { isCandidate(it) }
    }

    private fun scanDir(dir: File, title: String) = backgroundScan("A analisar $title…") {
        collectFiles(dir).sortedByDescending { it.length() }
    }

    private fun scanWhatsApp() = backgroundScan("A analisar WhatsApp…") {
        val root = Environment.getExternalStorageDirectory()
        val dirs = listOf(
            File(root, "Android/media/com.whatsapp/WhatsApp/Media"),
            File(root, "WhatsApp/Media"),
            File(root, "Android/media/com.whatsapp.w4b/WhatsApp Business/Media")
        )
        dirs.filter { it.exists() }.flatMap { collectFiles(it) }.sortedByDescending { it.length() }
    }

    private fun scanLargeFiles() = backgroundScan("A procurar ficheiros grandes…") {
        collectFiles(Environment.getExternalStorageDirectory()).filter { it.length() >= 500L*1024*1024 }.sortedByDescending { it.length() }
    }

    private fun scanApks() = backgroundScan("A procurar APKs…") {
        collectFiles(Environment.getExternalStorageDirectory()).filter { it.extension.equals("apk", true) }.sortedByDescending { it.lastModified() }
    }

    private fun scanDuplicates() = backgroundScan("A calcular duplicados…") {
        val files = collectFiles(Environment.getExternalStorageDirectory()).filter { it.length() > 0 && it.length() < 1024L*1024*1024 }
        val sizeGroups = files.groupBy { it.length() }.filterValues { it.size > 1 }
        val dups = mutableListOf<File>()
        sizeGroups.values.forEach { group ->
            group.groupBy { sha256(it) }.values.filter { it.size > 1 }.forEach { same -> dups.addAll(same.drop(1)) }
        }
        dups.sortedByDescending { it.length() }
    }

    private fun isCandidate(f: File): Boolean {
        val n = f.name.lowercase()
        val age = System.currentTimeMillis() - f.lastModified()
        return f.length() > 100L*1024*1024 || n.endsWith(".apk") || n.endsWith(".zip") || age > 180L*24*3600*1000
    }

    private fun collectFiles(start: File): List<File> {
        val out = mutableListOf<File>()
        val stack = ArrayDeque<File>(); if (start.exists()) stack.add(start)
        while (stack.isNotEmpty()) {
            val f = stack.removeLast()
            try {
                if (f.isDirectory) f.listFiles()?.forEach { child ->
                    if (child.isDirectory) {
                        val p = child.absolutePath
                        if (!p.contains("/Android/data/") && !p.contains("/Android/obb/")) stack.add(child)
                    } else out.add(child)
                }
            } catch (_: Exception) {}
        }
        return out
    }

    private fun sha256(file: File): String = try {
        val md = MessageDigest.getInstance("SHA-256")
        file.inputStream().use { input ->
            val b = ByteArray(1024*1024); var n: Int
            while (input.read(b).also { n=it } > 0) md.update(b,0,n)
        }
        md.digest().joinToString("") { "%02x".format(it) }
    } catch (_: Exception) { file.absolutePath }

    private fun backgroundScan(message: String, block: () -> List<File>) {
        progress.visibility = View.VISIBLE; status.text = message; results.removeAllViews(); candidates.clear()
        executor.execute {
            val data = try { block() } catch (_: Exception) { emptyList() }
            runOnUiThread {
                progress.visibility = View.GONE
                candidates.addAll(data.take(500))
                val total = candidates.sumOf { it.length() }
                status.text = "${candidates.size} ficheiros encontrados • ${Formatter.formatFileSize(this,total)}"
                renderResults()
            }
        }
    }

    private fun renderResults() {
        results.removeAllViews()
        if (candidates.isEmpty()) { results.addView(TextView(this).apply { text="Nada encontrado nesta análise." }); return }
        candidates.forEach { f ->
            val cb = CheckBox(this).apply {
                tag = f
                text = "${f.name}\n${Formatter.formatFileSize(this@MainActivity,f.length())}  •  ${f.parent ?: ""}"
                setPadding(0,8,0,8)
            }
            results.addView(cb)
        }
    }

    private fun confirmDelete() {
        val selected = (0 until results.childCount).mapNotNull { i ->
            val v = results.getChildAt(i); if (v is CheckBox && v.isChecked) v.tag as? File else null
        }
        if (selected.isEmpty()) { Toast.makeText(this,"Seleciona primeiro os ficheiros a eliminar.",Toast.LENGTH_SHORT).show(); return }
        val size = selected.sumOf { it.length() }
        AlertDialog.Builder(this).setTitle("Eliminar ficheiros?")
            .setMessage("Selecionaste ${selected.size} ficheiros (${Formatter.formatFileSize(this,size)}). Esta operação pode ser definitiva.")
            .setPositiveButton("Eliminar") { _, _ -> deleteSelected(selected) }
            .setNegativeButton("Cancelar", null).show()
    }

    private fun deleteSelected(files: List<File>) {
        var ok=0
        files.forEach { try { if (it.delete()) ok++ } catch (_:Exception) {} }
        Toast.makeText(this,"$ok de ${files.size} ficheiros eliminados.",Toast.LENGTH_LONG).show()
        candidates.removeAll(files.toSet()); renderResults(); showStorageSummary()
    }
}
