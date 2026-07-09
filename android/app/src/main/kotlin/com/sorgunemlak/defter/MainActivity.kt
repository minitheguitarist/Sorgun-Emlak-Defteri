package com.sorgunemlak.defter

import android.Manifest
import android.app.Activity
import android.content.ContentValues
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.ContactsContract
import android.provider.MediaStore
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    private var pendingPickerResult: MethodChannel.Result? = null
    private var pendingContactResult: MethodChannel.Result? = null

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
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.sorgunemlak.defter/contact_picker"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "pickContact" -> requestContactPicker(result)
                else -> result.notImplemented()
            }
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.sorgunemlak.defter/gallery_saver"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "saveAdvertisementPng" -> {
                    val bytes = call.argument<ByteArray>("bytes")
                    val fileName = call.argument<String>("fileName")
                    if (bytes == null || fileName.isNullOrBlank()) {
                        result.error("invalid_args", "Görsel veya dosya adı eksik.", null)
                        return@setMethodCallHandler
                    }
                    try {
                        result.success(saveAdvertisementPng(bytes, fileName))
                    } catch (error: Exception) {
                        result.error("save_failed", error.message, null)
                    }
                }
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

        if (requestCode == contactPickerRequestCode) {
            val result = pendingContactResult ?: return
            pendingContactResult = null

            val uri = data?.data
            if (resultCode != Activity.RESULT_OK || uri == null) {
                result.success(null)
                return
            }

            try {
                result.success(readContact(uri))
            } catch (error: Exception) {
                result.error("contact_read_failed", error.message, null)
            }
            return
        }

        super.onActivityResult(requestCode, resultCode, data)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != contactPermissionRequestCode) {
            return
        }

        if (grantResults.isNotEmpty() &&
            grantResults[0] == PackageManager.PERMISSION_GRANTED
        ) {
            openContactPicker()
            return
        }

        val result = pendingContactResult ?: return
        pendingContactResult = null
        result.error("permission_denied", "Rehber izni verilmedi.", null)
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

    private fun requestContactPicker(result: MethodChannel.Result) {
        if (pendingContactResult != null) {
            result.error("picker_busy", "Rehber seçici zaten açık.", null)
            return
        }

        pendingContactResult = result
        if (android.os.Build.VERSION.SDK_INT < 23 ||
            checkSelfPermission(Manifest.permission.READ_CONTACTS) ==
            PackageManager.PERMISSION_GRANTED
        ) {
            openContactPicker()
            return
        }

        requestPermissions(
            arrayOf(Manifest.permission.READ_CONTACTS),
            contactPermissionRequestCode
        )
    }

    private fun openContactPicker() {
        val intent = Intent(Intent.ACTION_PICK, ContactsContract.Contacts.CONTENT_URI)
        try {
            startActivityForResult(
                Intent.createChooser(intent, "Mülk sahibi seç"),
                contactPickerRequestCode
            )
        } catch (error: Exception) {
            val result = pendingContactResult ?: return
            pendingContactResult = null
            result.error("picker_unavailable", error.message, null)
        }
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

    private fun readContact(uri: Uri): Map<String, Any> {
        var contactId: String? = null
        var displayName = ""
        var hasPhoneNumber = false

        contentResolver.query(
            uri,
            arrayOf(
                ContactsContract.Contacts._ID,
                ContactsContract.Contacts.DISPLAY_NAME,
                ContactsContract.Contacts.HAS_PHONE_NUMBER
            ),
            null,
            null,
            null
        )?.use { cursor ->
            if (cursor.moveToFirst()) {
                val idIndex = cursor.getColumnIndex(ContactsContract.Contacts._ID)
                val nameIndex = cursor.getColumnIndex(ContactsContract.Contacts.DISPLAY_NAME)
                val hasPhoneIndex =
                    cursor.getColumnIndex(ContactsContract.Contacts.HAS_PHONE_NUMBER)
                if (idIndex >= 0) {
                    contactId = cursor.getString(idIndex)
                }
                if (nameIndex >= 0) {
                    displayName = cursor.getString(nameIndex) ?: ""
                }
                if (hasPhoneIndex >= 0) {
                    hasPhoneNumber = cursor.getInt(hasPhoneIndex) > 0
                }
            }
        }

        val phones = mutableListOf<String>()
        val id = contactId
        if (id != null && hasPhoneNumber) {
            contentResolver.query(
                ContactsContract.CommonDataKinds.Phone.CONTENT_URI,
                arrayOf(ContactsContract.CommonDataKinds.Phone.NUMBER),
                "${ContactsContract.CommonDataKinds.Phone.CONTACT_ID} = ?",
                arrayOf(id),
                null
            )?.use { cursor ->
                val numberIndex =
                    cursor.getColumnIndex(ContactsContract.CommonDataKinds.Phone.NUMBER)
                while (numberIndex >= 0 && cursor.moveToNext()) {
                    val phone = cursor.getString(numberIndex)?.trim()
                    if (!phone.isNullOrEmpty() && !phones.contains(phone)) {
                        phones.add(phone)
                    }
                }
            }
        }

        return mapOf(
            "name" to displayName,
            "phones" to phones
        )
    }

    private fun safeFileName(value: String): String {
        return value.replace(Regex("[^A-Za-z0-9._-]"), "_")
    }

    private fun saveAdvertisementPng(bytes: ByteArray, fileName: String): String {
        val safeName = safeFileName(
            if (fileName.lowercase().endsWith(".png")) fileName else "$fileName.png"
        )

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val values = ContentValues().apply {
                put(MediaStore.Images.Media.DISPLAY_NAME, safeName)
                put(MediaStore.Images.Media.MIME_TYPE, "image/png")
                put(
                    MediaStore.Images.Media.RELATIVE_PATH,
                    "${Environment.DIRECTORY_PICTURES}/Sorgun Emlak Defteri"
                )
                put(MediaStore.Images.Media.IS_PENDING, 1)
            }
            val uri = contentResolver.insert(
                MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
                values
            ) ?: throw IllegalStateException("Galeri dosyası oluşturulamadı.")

            contentResolver.openOutputStream(uri)?.use { output ->
                output.write(bytes)
            } ?: throw IllegalStateException("Galeri dosyası yazılamadı.")

            values.clear()
            values.put(MediaStore.Images.Media.IS_PENDING, 0)
            contentResolver.update(uri, values, null, null)
            return uri.toString()
        }

        val pictures = Environment.getExternalStoragePublicDirectory(
            Environment.DIRECTORY_PICTURES
        )
        val directory = File(pictures, "Sorgun Emlak Defteri")
        if (!directory.exists()) {
            directory.mkdirs()
        }
        val destination = File(directory, safeName)
        FileOutputStream(destination).use { output ->
            output.write(bytes)
        }
        sendBroadcast(Intent(Intent.ACTION_MEDIA_SCANNER_SCAN_FILE, Uri.fromFile(destination)))
        return destination.absolutePath
    }

    companion object {
        private const val packagePickerRequestCode = 6417
        private const val contactPickerRequestCode = 6418
        private const val contactPermissionRequestCode = 6419
    }
}
