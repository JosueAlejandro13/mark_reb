package com.example.mark_v3

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage

class MyFirebaseMessagingService : FirebaseMessagingService() {

    override fun onMessageReceived(remoteMessage: RemoteMessage) {
        remoteMessage.notification?.let {
            val title = it.title.orEmpty() 
            val body = it.body.orEmpty()   
            sendNotification(title, body)
        }
    }

    override fun onNewToken(token: String) {
        // Manejar el nuevo token si es necesario
    }

private fun sendNotification(title: String, message: String) {
    val channelId = "default_channel_id"
    val notificationId = 1001

    val intent = Intent(this, MainActivity::class.java)
    val pendingIntent = PendingIntent.getActivity(
        this, 0, intent, PendingIntent.FLAG_IMMUTABLE
    )

    val bigTextStyle = NotificationCompat.BigTextStyle().bigText(message)

    val builder = NotificationCompat.Builder(this, channelId)
        .setSmallIcon(R.drawable.iconik) 
        .setContentTitle(title)
        .setContentText(message)
        .setStyle(bigTextStyle)
        .setPriority(NotificationCompat.PRIORITY_HIGH)
        .setContentIntent(pendingIntent)
        .setAutoCancel(true)

        

    val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
        val channel = NotificationChannel(channelId, "Notificaciones", NotificationManager.IMPORTANCE_HIGH)
        notificationManager.createNotificationChannel(channel)
    }

    notificationManager.notify(notificationId, builder.build())
}

}

