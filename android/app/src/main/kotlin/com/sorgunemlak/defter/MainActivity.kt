package com.sorgunemlak.defter

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    private var pendingPickerResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.sorgunemlak.defter/file_picker"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "pickSedefPackage" -> openPackagePicker(result)
                else -> result.notImplemented()
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode == packagePickerRequestCode) {
            val result = pendingPickerResult ?: return
            pendingPickerResult = null

            val uri = data?.data
            if (resultCode != Activity.RESULT_OK || uri == null) {
                result.success(null)
                return
            }

            try {
                result.success(copyPackageToCache(uri))
            } catch (error: Exception) {
                result.error("copy_failed", error.message, null)
            }
            return
        }

        super.onActivityResult(requestCode, resultCode, data)
    }

    private fun openPackagePicker(result: MethodChannel.Result) {
        if (pendingPickerResult != null) {
            result.error("picker_busy", "Dosya seçici zaten açık.", null)
            return
        }

        pendingPickerResult = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "*/*"
            putExtra(
                Intent.EXTRA_MIME_TYPES,
                arrayOf(
                    "application/octet-stream",
                    "application/zip",
                    "application/x-zip-compressed"
                )
            )
        }
        startActivityForResult(
            Intent.createChooser(intent, "Paylaşım paketi seç"),
            packagePickerRequestCode
        )
    }

    private fun copyPackageToCache(uri: Uri): String {
        val directory = File(cacheDir, "picked_packages")
        if (!directory.exists()) {
            directory.mkdirs()
        }

        val fileName = safeFileName(queryFileName(uri) ?: "sorgun-emlak-defteri.sedef")
        val destination = File(directory, "${System.currentTimeMillis()}_$fileName")
        val input = contentResolver.openInputStream(uri)
            ?: throw IllegalStateException("Dosya okunamadı.")

        input.use { source ->
            FileOutputStream(destination).use { output ->
                source.copyTo(output)
            }
        }
        return destination.absolutePath
    }

    private fun queryFileName(uri: Uri): String? {
        contentResolver.query(uri, null, null, null, null)?.use { cursor ->
            val nameIndex = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
            if (nameIndex >= 0 && cursor.moveToFirst()) {
                return cursor.getString(nameIndex)
            }
        }
        return null
    }

    private fun safeFileName(value: String): String {
        return value.replace(Regex("[^A-Za-z0-9._-]"), "_")
    }

    companion object {
        private const val packagePickerRequestCode = 6417
    }
}
