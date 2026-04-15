package com.talkingcards.app

import android.content.Context
import android.net.Uri
import com.google.android.engage.service.AppEngagePublishClient
import com.google.android.engage.service.PublishRecommendationClustersRequest
import com.google.android.engage.service.PublishContinuationClusterRequest
import com.google.android.engage.common.datamodel.ContinuationCluster
import com.google.android.engage.common.datamodel.RecommendationCluster
import com.google.android.engage.common.datamodel.Image

object EngagePublisher {

    fun publish(context: Context, args: Map<String, Any?>) {
        val client = AppEngagePublishClient(context)
        client.isServiceAvailable.addOnSuccessListener { available ->
            if (!available) return@addOnSuccessListener
            publishContinuation(client, args)
            publishRecommendations(client, args)
        }
    }

    private fun publishContinuation(client: AppEngagePublishClient, args: Map<String, Any?>) {
        val packId = args["lastPackId"] as? String ?: return
        val packTitle = args["lastPackTitle"] as? String ?: return
        val questDone = (args["questDone"] as? Int) ?: 0
        val questTotal = (args["questTotal"] as? Int) ?: 5
        val streak = (args["streak"] as? Int) ?: 0

        // TODO: Replace with the correct entity class for your Engage SDK vertical.
        // After enrolling at https://developer.android.com/engage, Google will
        // confirm which entity type to use (e.g. ArticleEntity, VideoClusterEntity,
        // or a generic type). The cluster + request setup below is correct.
        //
        // Example using a hypothetical generic entity:
        //   val entity = GenericEntity.Builder()
        //       .setUri(Uri.parse("talkingcards://cards/$packId"))
        //       .setTitle(packTitle)
        //       .setSubtitle("Завдання: $questDone/$questTotal · Стрік: $streak")
        //       .setLastEngagementTimeMillis(System.currentTimeMillis())
        //       .build()
        //   val cluster = ContinuationCluster.Builder().addEntity(entity).build()

        val cluster = ContinuationCluster.Builder().build()

        client.publishContinuationCluster(
            PublishContinuationClusterRequest.Builder()
                .setContinuationCluster(cluster)
                .build()
        )
    }

    @Suppress("UNCHECKED_CAST")
    private fun publishRecommendations(client: AppEngagePublishClient, args: Map<String, Any?>) {
        val packs = args["recommendedPacks"] as? List<Map<String, String>> ?: return
        if (packs.isEmpty()) return

        // TODO: Replace with the correct entity class for your Engage SDK vertical.
        // Example using a hypothetical generic entity:
        //   val entities = packs.take(3).mapNotNull { pack ->
        //       val id = pack["id"] ?: return@mapNotNull null
        //       val title = pack["title"] ?: return@mapNotNull null
        //       GenericEntity.Builder()
        //           .setUri(Uri.parse("talkingcards://cards/$id"))
        //           .setTitle(title)
        //           .build()
        //   }
        //   val cluster = RecommendationCluster.Builder()
        //       .setTitle("Вивчай далі")
        //       .also { builder -> entities.forEach { builder.addEntity(it) } }
        //       .build()

        val cluster = RecommendationCluster.Builder()
            .setTitle("Вивчай далі")
            .build()

        client.publishRecommendationClusters(
            PublishRecommendationClustersRequest.Builder()
                .addRecommendationCluster(cluster)
                .build()
        )
    }
}
