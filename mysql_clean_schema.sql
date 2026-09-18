-- SAKI clean MariaDB schema generated from the Supabase public schema.

-- No historical data is included. IDs and relationships are kept compatible.

SET NAMES utf8mb4;

SET FOREIGN_KEY_CHECKS=0;

CREATE TABLE IF NOT EXISTS `profiles` (
`id` char(36) NOT NULL,
`username` varchar(255) NOT NULL,
`saki_id` bigint NULL DEFAULT NULL,
`avatar_url` longtext NULL DEFAULT NULL,
`bio` longtext NULL DEFAULT NULL,
`country` longtext NULL DEFAULT NULL,
`gender` longtext NULL DEFAULT NULL,
`created_at` timestamp NOT NULL,
`country_code` longtext NOT NULL,
`display_name` longtext NULL DEFAULT NULL,
`is_private` tinyint(1) NOT NULL DEFAULT 0,
`updated_at` timestamp NOT NULL,
`vip_level` int NOT NULL DEFAULT 0,
`vip_expires_at` timestamp NULL DEFAULT NULL,
`is_super_admin` tinyint(1) NOT NULL DEFAULT 0,
`super_admin_label` longtext NULL DEFAULT NULL,
`wealth_xp` bigint NOT NULL DEFAULT 0,
`wealth_level` int NOT NULL DEFAULT 0,
`charm_xp` bigint NOT NULL DEFAULT 0,
`charm_level` int NOT NULL DEFAULT 0,
`vip_frame_enabled` tinyint(1) NOT NULL DEFAULT 0,
`country_updated_at` timestamp NULL DEFAULT NULL,
`admin_role` varchar(255) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_profiles_username` (`username`),
  UNIQUE KEY `uq_profiles_saki_id` (`saki_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `posts` (
`id` char(36) NOT NULL,
`author_id` char(36) NOT NULL,
`content` longtext NULL DEFAULT NULL,
`visibility` longtext NOT NULL,
`created_at` timestamp NOT NULL,
`updated_at` timestamp NOT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_posts_author_id` (`author_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `post_media` (
`id` char(36) NOT NULL,
`post_id` char(36) NOT NULL,
`storage_path` longtext NOT NULL,
`sort_order` int NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_post_media_post_id` (`post_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `post_likes` (
`post_id` char(36) NOT NULL,
`user_id` char(36) NOT NULL,
`created_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`post_id`, `user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `follows` (
`follower_id` char(36) NOT NULL,
`following_id` char(36) NOT NULL,
`created_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`follower_id`, `following_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `rooms` (
`id` char(36) NOT NULL,
`owner_id` char(36) NOT NULL,
`name` longtext NOT NULL,
`description` longtext NULL DEFAULT NULL,
`country` longtext NULL DEFAULT NULL,
`room_type` longtext NULL DEFAULT NULL,
`created_at` timestamp NOT NULL,
`room_id` varchar(255) NULL DEFAULT NULL,
`image_url` longtext NULL DEFAULT NULL,
`is_active` tinyint(1) NOT NULL DEFAULT 0,
`seat_count` int NOT NULL DEFAULT 0,
`background_url` longtext NULL DEFAULT NULL,
`is_official` tinyint(1) NOT NULL DEFAULT 0,
`announcement` longtext NULL DEFAULT NULL,
`category` longtext NOT NULL,
`theme_key` longtext NOT NULL,
`membership_fee` int NOT NULL DEFAULT 0,
`reward_rate` decimal(20,6) NOT NULL DEFAULT 0,
`mic_permission` longtext NOT NULL,
`is_pinned` tinyint(1) NOT NULL DEFAULT 0,
`pin_priority` int NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_rooms_owner_id` (`owner_id`),
  KEY `idx_rooms_room_id` (`room_id`(36))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `conversations` (
`id` char(36) NOT NULL,
`created_at` timestamp NOT NULL,
`created_by` char(36) NULL DEFAULT NULL,
`updated_at` timestamp NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `conversation_members` (
`conversation_id` char(36) NOT NULL,
`user_id` char(36) NOT NULL,
  PRIMARY KEY (`conversation_id`, `user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `messages` (
`id` char(36) NOT NULL,
`conversation_id` char(36) NULL DEFAULT NULL,
`sender_id` char(36) NULL DEFAULT NULL,
`body` longtext NOT NULL,
`created_at` timestamp NOT NULL,
`is_read` tinyint(1) NOT NULL DEFAULT 0,
`message_type` longtext NOT NULL,
`media_url` longtext NULL DEFAULT NULL,
`media_name` longtext NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_messages_conversation_id` (`conversation_id`),
  KEY `idx_messages_sender_id` (`sender_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `post_comments` (
`id` char(36) NOT NULL,
`post_id` char(36) NOT NULL,
`user_id` char(36) NOT NULL,
`content` longtext NOT NULL,
`created_at` timestamp NOT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_post_comments_post_id` (`post_id`),
  KEY `idx_post_comments_user_id` (`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `reels` (
`id` char(36) NOT NULL,
`author_id` char(36) NOT NULL,
`video_url` longtext NOT NULL,
`description` longtext NULL DEFAULT NULL,
`visibility` longtext NOT NULL,
`created_at` timestamp NOT NULL,
`updated_at` timestamp NOT NULL,
`thumbnail_url` longtext NULL DEFAULT NULL,
`video_path` longtext NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_reels_author_id` (`author_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `room_members` (
`room_id` char(36) NOT NULL,
`user_id` char(36) NOT NULL,
`joined_at` timestamp NOT NULL,
`last_seen` timestamp NOT NULL,
  PRIMARY KEY (`room_id`, `user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `notifications` (
`id` char(36) NOT NULL,
`user_id` char(36) NOT NULL,
`actor_id` char(36) NULL DEFAULT NULL,
`type` varchar(255) NOT NULL,
`entity_id` char(36) NULL DEFAULT NULL,
`is_read` tinyint(1) NOT NULL DEFAULT 0,
`created_at` timestamp NOT NULL,
`badge_key` longtext NULL DEFAULT NULL,
`badge_asset_path` longtext NULL DEFAULT NULL,
`data` longtext NOT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_notifications_user_id` (`user_id`),
  KEY `idx_notifications_actor_id` (`actor_id`),
  KEY `idx_notifications_entity_id` (`entity_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `reel_comments` (
`id` char(36) NOT NULL,
`reel_id` char(36) NOT NULL,
`user_id` char(36) NOT NULL,
`content` longtext NOT NULL,
`created_at` timestamp NOT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_reel_comments_reel_id` (`reel_id`),
  KEY `idx_reel_comments_user_id` (`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `reel_likes` (
`reel_id` char(36) NOT NULL,
`user_id` char(36) NOT NULL,
`created_at` timestamp NOT NULL,
  PRIMARY KEY (`reel_id`, `user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `post_shares` (
`post_id` char(36) NOT NULL,
`user_id` char(36) NOT NULL,
`created_at` timestamp NOT NULL,
  PRIMARY KEY (`post_id`, `user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `reel_media` (
`id` char(36) NOT NULL,
`reel_id` char(36) NOT NULL,
`storage_path` longtext NOT NULL,
`sort_order` int NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_reel_media_reel_id` (`reel_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `reel_shares` (
`reel_id` char(36) NOT NULL,
`user_id` char(36) NOT NULL,
`created_at` timestamp NOT NULL,
  PRIMARY KEY (`reel_id`, `user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `room_messages` (
`id` char(36) NOT NULL,
`room_id` char(36) NOT NULL,
`sender_id` char(36) NOT NULL,
`body` longtext NOT NULL,
`created_at` timestamp NOT NULL,
`message_type` longtext NOT NULL,
`payload` longtext NOT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_room_messages_room_id` (`room_id`),
  KEY `idx_room_messages_sender_id` (`sender_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `room_banners` (
`id` char(36) NOT NULL,
`image_url` longtext NOT NULL,
`title` longtext NULL DEFAULT NULL,
`sort_order` int NOT NULL DEFAULT 0,
`is_active` tinyint(1) NOT NULL DEFAULT 0,
`created_at` timestamp NOT NULL,
`target_type` longtext NOT NULL,
`target_user_id` char(36) NULL DEFAULT NULL,
`target_room_id` char(36) NULL DEFAULT NULL,
`starts_at` timestamp NULL DEFAULT NULL,
`ends_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_room_banners_target_user_id` (`target_user_id`),
  KEY `idx_room_banners_target_room_id` (`target_room_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `countries` (
`code` varchar(255) NOT NULL,
`name` longtext NOT NULL,
`name_ar` longtext NOT NULL,
`flag` longtext NOT NULL,
  PRIMARY KEY (`code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `saki_account_modules` (
`user_id` char(36) NOT NULL,
`wallet_balance` decimal(20,6) NOT NULL DEFAULT 0,
`wallet_currency` longtext NOT NULL,
`vip_level` int NOT NULL DEFAULT 0,
`vip_label` longtext NOT NULL,
`aristocracy_label` longtext NOT NULL,
`store_credit` decimal(20,6) NOT NULL DEFAULT 0,
`settings` longtext NOT NULL,
`created_at` timestamp NOT NULL,
`updated_at` timestamp NOT NULL,
`gold_coins` bigint NOT NULL DEFAULT 0,
`diamonds` bigint NOT NULL DEFAULT 0,
`vip_points` bigint NOT NULL DEFAULT 0,
`wealth_xp` bigint NOT NULL DEFAULT 0,
`wealth_level` int NOT NULL DEFAULT 0,
`charm_xp` bigint NOT NULL DEFAULT 0,
`charm_level` int NOT NULL DEFAULT 0,
  PRIMARY KEY (`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `room_seats` (
`room_id` char(36) NOT NULL,
`seat_no` int NOT NULL DEFAULT 0,
`user_id` char(36) NOT NULL,
`joined_at` timestamp NOT NULL,
`is_speaking` tinyint(1) NOT NULL DEFAULT 0,
  PRIMARY KEY (`room_id`, `seat_no`),
  KEY `idx_room_seats_user_id` (`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `room_follows` (
`room_id` char(36) NOT NULL,
`user_id` char(36) NOT NULL,
`created_at` timestamp NOT NULL,
  PRIMARY KEY (`room_id`, `user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `vip_transactions` (
`id` char(36) NOT NULL,
`sender_id` char(36) NOT NULL,
`recipient_id` char(36) NOT NULL,
`vip_level` int NOT NULL DEFAULT 0,
`price` bigint NOT NULL DEFAULT 0,
`transaction_type` longtext NOT NULL,
`created_at` timestamp NOT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_vip_transactions_sender_id` (`sender_id`),
  KEY `idx_vip_transactions_recipient_id` (`recipient_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `room_moderators` (
`room_id` char(36) NOT NULL,
`user_id` char(36) NOT NULL,
`created_by` char(36) NOT NULL,
`created_at` timestamp NOT NULL,
  PRIMARY KEY (`room_id`, `user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `room_bans` (
`room_id` char(36) NOT NULL,
`user_id` char(36) NOT NULL,
`banned_by` char(36) NOT NULL,
`expires_at` timestamp NULL DEFAULT NULL,
`created_at` timestamp NOT NULL,
  PRIMARY KEY (`room_id`, `user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `room_mutes` (
`room_id` char(36) NOT NULL,
`user_id` char(36) NOT NULL,
`muted_by` char(36) NOT NULL,
`expires_at` timestamp NULL DEFAULT NULL,
`created_at` timestamp NOT NULL,
`mute_voice` tinyint(1) NOT NULL DEFAULT 0,
`mute_chat` tinyint(1) NOT NULL DEFAULT 0,
  PRIMARY KEY (`room_id`, `user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `room_seat_invites` (
`id` char(36) NOT NULL,
`room_id` char(36) NOT NULL,
`inviter_id` char(36) NOT NULL,
`invitee_id` char(36) NOT NULL,
`status` varchar(255) NOT NULL,
`created_at` timestamp NOT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_room_seat_invites_room_id` (`room_id`),
  KEY `idx_room_seat_invites_inviter_id` (`inviter_id`),
  KEY `idx_room_seat_invites_invitee_id` (`invitee_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `room_backgrounds` (
`id` char(36) NOT NULL,
`room_id` char(36) NOT NULL,
`owner_id` char(36) NOT NULL,
`image_url` longtext NOT NULL,
`created_at` timestamp NOT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_room_backgrounds_room_id` (`room_id`),
  KEY `idx_room_backgrounds_owner_id` (`owner_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `room_gift_catalog` (
`id` char(36) NOT NULL,
`category` longtext NOT NULL,
`name` longtext NOT NULL,
`icon` longtext NOT NULL,
`price` bigint NOT NULL DEFAULT 0,
`sort_order` int NOT NULL DEFAULT 0,
`is_active` tinyint(1) NOT NULL DEFAULT 0,
`media_url` longtext NULL DEFAULT NULL,
`media_type` longtext NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `room_gifts` (
`id` char(36) NOT NULL,
`room_id` char(36) NOT NULL,
`sender_id` char(36) NOT NULL,
`recipient_id` char(36) NOT NULL,
`gift_id` char(36) NOT NULL,
`quantity` int NOT NULL DEFAULT 0,
`total_price` bigint NOT NULL DEFAULT 0,
`created_at` timestamp NOT NULL,
`recipient_diamonds` bigint NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_room_gifts_room_id` (`room_id`),
  KEY `idx_room_gifts_sender_id` (`sender_id`),
  KEY `idx_room_gifts_recipient_id` (`recipient_id`),
  KEY `idx_room_gifts_gift_id` (`gift_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `room_gift_inventory` (
`user_id` char(36) NOT NULL,
`gift_id` char(36) NOT NULL,
`quantity` bigint NOT NULL DEFAULT 0,
  PRIMARY KEY (`user_id`, `gift_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `app_bans` (
`user_id` char(36) NOT NULL,
`banned_by` char(36) NOT NULL,
`expires_at` timestamp NULL DEFAULT NULL,
`reason` longtext NULL DEFAULT NULL,
`created_at` timestamp NOT NULL,
  PRIMARY KEY (`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `gift_announcements` (
`id` char(36) NOT NULL,
`room_id` char(36) NOT NULL,
`sender_id` char(36) NOT NULL,
`recipient_id` char(36) NOT NULL,
`gift_id` char(36) NOT NULL,
`total_price` bigint NOT NULL DEFAULT 0,
`recipient_diamonds` bigint NOT NULL DEFAULT 0,
`created_at` timestamp NOT NULL,
`event_type` longtext NOT NULL,
`multiplier` int NOT NULL DEFAULT 0,
`reward_gold` bigint NOT NULL DEFAULT 0,
`gift_price` bigint NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_gift_announcements_room_id` (`room_id`),
  KEY `idx_gift_announcements_sender_id` (`sender_id`),
  KEY `idx_gift_announcements_recipient_id` (`recipient_id`),
  KEY `idx_gift_announcements_gift_id` (`gift_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `trace_store_catalog` (
`id` char(36) NOT NULL,
`category` longtext NOT NULL,
`name` longtext NOT NULL,
`asset_key` longtext NOT NULL,
`price_gold_coins` bigint NOT NULL DEFAULT 0,
`duration_days` int NULL DEFAULT NULL,
`is_active` tinyint(1) NOT NULL DEFAULT 0,
`sort_order` int NOT NULL DEFAULT 0,
`created_at` timestamp NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `trace_store_inventory` (
`user_id` char(36) NOT NULL,
`item_id` char(36) NOT NULL,
`purchased_at` timestamp NOT NULL,
`expires_at` timestamp NULL DEFAULT NULL,
`is_active` tinyint(1) NOT NULL DEFAULT 0,
  PRIMARY KEY (`user_id`, `item_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `trace_agencies` (
`id` char(36) NOT NULL,
`owner_id` char(36) NOT NULL,
`name` longtext NOT NULL,
`agent_code` varchar(255) NOT NULL,
`status` varchar(255) NOT NULL,
`created_at` timestamp NOT NULL,
`country` longtext NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_trace_agencies_agent_code` (`agent_code`),
  KEY `idx_trace_agencies_owner_id` (`owner_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `trace_agency_members` (
`agency_id` char(36) NOT NULL,
`user_id` char(36) NOT NULL,
`role` varchar(255) NOT NULL,
`status` varchar(255) NOT NULL,
`joined_at` timestamp NOT NULL,
  PRIMARY KEY (`agency_id`, `user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `trace_agency_join_requests` (
`id` char(36) NOT NULL,
`agency_id` char(36) NOT NULL,
`user_id` char(36) NOT NULL,
`status` varchar(255) NOT NULL,
`created_at` timestamp NOT NULL,
`reviewed_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_trace_agency_join_requests_agency_id` (`agency_id`),
  KEY `idx_trace_agency_join_requests_user_id` (`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `trace_families` (
`id` char(36) NOT NULL,
`owner_id` char(36) NOT NULL,
`name` longtext NOT NULL,
`invite_code` varchar(255) NOT NULL,
`status` varchar(255) NOT NULL,
`created_at` timestamp NOT NULL,
`avatar_url` longtext NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_trace_families_invite_code` (`invite_code`),
  KEY `idx_trace_families_owner_id` (`owner_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `trace_family_members` (
`family_id` char(36) NOT NULL,
`user_id` char(36) NOT NULL,
`role` varchar(255) NOT NULL,
`status` varchar(255) NOT NULL,
`joined_at` timestamp NOT NULL,
  PRIMARY KEY (`family_id`, `user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `trace_user_levels` (
`user_id` char(36) NOT NULL,
`experience_points` bigint NOT NULL DEFAULT 0,
`level` int NOT NULL DEFAULT 0,
`updated_at` timestamp NOT NULL,
  PRIMARY KEY (`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `trace_level_rewards` (
`id` char(36) NOT NULL,
`level` int NOT NULL DEFAULT 0,
`title` longtext NOT NULL,
`description` longtext NOT NULL,
`reward_type` longtext NOT NULL,
`reward_value` longtext NOT NULL,
`created_at` timestamp NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_trace_level_rewards_level` (`level`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `pk_battles` (
`id` char(36) NOT NULL,
`room_id` char(36) NOT NULL,
`channel_name` longtext NOT NULL,
`host_id` char(36) NOT NULL,
`opponent_id` char(36) NULL DEFAULT NULL,
`status` varchar(255) NOT NULL,
`host_score` bigint NOT NULL DEFAULT 0,
`opponent_score` bigint NOT NULL DEFAULT 0,
`duration_seconds` int NOT NULL DEFAULT 0,
`started_at` timestamp NULL DEFAULT NULL,
`ends_at` timestamp NULL DEFAULT NULL,
`winner_id` char(36) NULL DEFAULT NULL,
`created_at` timestamp NOT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_pk_battles_room_id` (`room_id`),
  KEY `idx_pk_battles_host_id` (`host_id`),
  KEY `idx_pk_battles_opponent_id` (`opponent_id`),
  KEY `idx_pk_battles_winner_id` (`winner_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `live_broadcasts` (
`id` char(36) NOT NULL,
`room_id` char(36) NOT NULL,
`host_id` char(36) NOT NULL,
`channel_name` varchar(255) NOT NULL,
`title` longtext NOT NULL,
`avatar_url` longtext NULL DEFAULT NULL,
`status` varchar(255) NOT NULL,
`started_at` timestamp NOT NULL,
`ended_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_live_broadcasts_channel_name` (`channel_name`),
  KEY `idx_live_broadcasts_room_id` (`room_id`),
  KEY `idx_live_broadcasts_host_id` (`host_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `room_activity_logs` (
`id` char(36) NOT NULL,
`room_id` char(36) NOT NULL,
`actor_id` char(36) NOT NULL,
`action` longtext NOT NULL,
`target_user_id` char(36) NULL DEFAULT NULL,
`metadata` longtext NOT NULL,
`created_at` timestamp NOT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_room_activity_logs_room_id` (`room_id`),
  KEY `idx_room_activity_logs_actor_id` (`actor_id`),
  KEY `idx_room_activity_logs_target_user_id` (`target_user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `saki_wheel_rounds` (
`id` bigint NOT NULL AUTO_INCREMENT,
`room_id` char(36) NOT NULL,
`round_no` bigint NOT NULL DEFAULT 0,
`status` varchar(255) NOT NULL,
`betting_ends_at` timestamp NOT NULL,
`result_ends_at` timestamp NOT NULL,
`winning_food` longtext NULL DEFAULT NULL,
`created_at` timestamp NOT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_saki_wheel_rounds_room_id` (`room_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `saki_wheel_bets` (
`id` bigint NOT NULL AUTO_INCREMENT,
`round_id` bigint NOT NULL DEFAULT 0,
`room_id` char(36) NOT NULL,
`user_id` char(36) NOT NULL,
`food_key` longtext NOT NULL,
`amount` bigint NOT NULL DEFAULT 0,
`created_at` timestamp NOT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_saki_wheel_bets_round_id` (`round_id`),
  KEY `idx_saki_wheel_bets_room_id` (`room_id`),
  KEY `idx_saki_wheel_bets_user_id` (`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `saki_store_products` (
`id` char(36) NOT NULL,
`category` longtext NOT NULL,
`name` longtext NOT NULL,
`price` bigint NOT NULL DEFAULT 0,
`media_type` longtext NOT NULL,
`media_url` longtext NOT NULL,
`thumbnail_url` longtext NOT NULL,
`is_active` tinyint(1) NOT NULL DEFAULT 0,
`created_at` timestamp NOT NULL,
`duration_days` int NOT NULL DEFAULT 0,
`discount_percent` decimal(20,6) NOT NULL DEFAULT 0,
`discounted_price` bigint NULL DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `saki_store_inventory` (
`user_id` char(36) NOT NULL,
`product_id` char(36) NOT NULL,
`quantity` int NOT NULL DEFAULT 0,
`equipped` tinyint(1) NOT NULL DEFAULT 0,
`purchased_at` timestamp NOT NULL,
`expires_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`user_id`, `product_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `saki_store_entrance_plays` (
`id` char(36) NOT NULL,
`room_id` char(36) NOT NULL,
`user_id` char(36) NOT NULL,
`product_id` char(36) NOT NULL,
`play_token` char(36) NOT NULL,
`created_at` timestamp NOT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_saki_store_entrance_plays_room_id` (`room_id`),
  KEY `idx_saki_store_entrance_plays_user_id` (`user_id`),
  KEY `idx_saki_store_entrance_plays_product_id` (`product_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `room_emojis` (
`id` char(36) NOT NULL,
`name` longtext NOT NULL,
`gif_url` longtext NOT NULL,
`is_active` tinyint(1) NOT NULL DEFAULT 0,
`created_at` timestamp NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `room_emoji_events` (
`id` char(36) NOT NULL,
`room_id` char(36) NOT NULL,
`user_id` char(36) NOT NULL,
`emoji_id` char(36) NOT NULL,
`created_at` timestamp NOT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_room_emoji_events_room_id` (`room_id`),
  KEY `idx_room_emoji_events_user_id` (`user_id`),
  KEY `idx_room_emoji_events_emoji_id` (`emoji_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `families` (
`id` char(36) NOT NULL,
`h_id` bigint NOT NULL DEFAULT 0,
`owner_id` char(36) NOT NULL,
`name` longtext NOT NULL,
`family_alias` varchar(255) NOT NULL,
`description` longtext NOT NULL,
`avatar_url` longtext NULL DEFAULT NULL,
`level` int NOT NULL DEFAULT 0,
`points` bigint NOT NULL DEFAULT 0,
`stars` bigint NOT NULL DEFAULT 0,
`created_at` timestamp NOT NULL,
`announcement` longtext NOT NULL,
`weekly_points` bigint NOT NULL DEFAULT 0,
`weekly_starts_at` timestamp NOT NULL,
`updated_at` timestamp NOT NULL,
`weekly_level` int NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_families_h_id` (`h_id`),
  UNIQUE KEY `uq_families_family_alias` (`family_alias`),
  KEY `idx_families_owner_id` (`owner_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `family_members` (
`family_id` char(36) NOT NULL,
`user_id` char(36) NOT NULL,
`role` varchar(255) NOT NULL,
`status` varchar(255) NOT NULL,
`joined_at` timestamp NOT NULL,
  PRIMARY KEY (`family_id`, `user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `family_join_requests` (
`id` char(36) NOT NULL,
`family_id` char(36) NOT NULL,
`user_id` char(36) NOT NULL,
`status` varchar(255) NOT NULL,
`created_at` timestamp NOT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_family_join_requests_family_id` (`family_id`),
  KEY `idx_family_join_requests_user_id` (`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `family_tasks` (
`id` char(36) NOT NULL,
`family_id` char(36) NOT NULL,
`title` longtext NOT NULL,
`target` bigint NOT NULL DEFAULT 0,
`progress` bigint NOT NULL DEFAULT 0,
`reward_points` bigint NOT NULL DEFAULT 0,
`period` longtext NOT NULL,
`created_at` timestamp NOT NULL,
`task_key` longtext NOT NULL,
`daily_target` bigint NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_family_tasks_family_id` (`family_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `user_blocks` (
`blocker_id` char(36) NOT NULL,
`blocked_id` char(36) NOT NULL,
`created_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`blocker_id`, `blocked_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `user_reports` (
`id` char(36) NOT NULL,
`reporter_id` char(36) NOT NULL,
`reported_id` char(36) NOT NULL,
`category` longtext NOT NULL,
`details` longtext NULL DEFAULT NULL,
`created_at` timestamp NULL DEFAULT NULL,
`room_id` char(36) NULL DEFAULT NULL,
`evidence_url` longtext NULL DEFAULT NULL,
`status` varchar(255) NOT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_user_reports_reporter_id` (`reporter_id`),
  KEY `idx_user_reports_reported_id` (`reported_id`),
  KEY `idx_user_reports_room_id` (`room_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `room_music` (
`id` char(36) NOT NULL,
`room_id` char(36) NULL DEFAULT NULL,
`owner_id` char(36) NOT NULL,
`title` longtext NOT NULL,
`storage_path` longtext NOT NULL,
`audio_url` longtext NOT NULL,
`created_at` timestamp NOT NULL,
`artist` longtext NOT NULL,
`cover_url` longtext NULL DEFAULT NULL,
`duration_seconds` longtext NOT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_room_music_room_id` (`room_id`),
  KEY `idx_room_music_owner_id` (`owner_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `room_music_state` (
`room_id` char(36) NOT NULL,
`music_id` char(36) NULL DEFAULT NULL,
`is_playing` tinyint(1) NOT NULL DEFAULT 0,
`position_seconds` longtext NOT NULL,
`updated_by` char(36) NULL DEFAULT NULL,
`updated_at` timestamp NOT NULL,
`owner_id` char(36) NULL DEFAULT NULL,
`volume` longtext NOT NULL,
`started_at` timestamp NULL DEFAULT NULL,
`repeat_mode` longtext NOT NULL,
`shuffle_mode` tinyint(1) NOT NULL DEFAULT 0,
  PRIMARY KEY (`room_id`),
  KEY `idx_room_music_state_music_id` (`music_id`),
  KEY `idx_room_music_state_owner_id` (`owner_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `family_task_progress` (
`family_id` char(36) NOT NULL,
`task_id` char(36) NOT NULL,
`user_id` char(36) NOT NULL,
`task_date` date NOT NULL,
`progress` bigint NOT NULL DEFAULT 0,
`completed_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`task_id`, `user_id`, `task_date`),
  KEY `idx_family_task_progress_family_id` (`family_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `family_weekly_rewards` (
`id` char(36) NOT NULL,
`family_id` char(36) NOT NULL,
`week_start` date NOT NULL,
`user_id` char(36) NOT NULL,
`sent_gold` bigint NOT NULL DEFAULT 0,
`reward_gold` bigint NOT NULL DEFAULT 0,
`rank` int NOT NULL DEFAULT 0,
`created_at` timestamp NOT NULL,
`owner_bonus_gold` bigint NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_family_weekly_rewards_family_id` (`family_id`),
  KEY `idx_family_weekly_rewards_user_id` (`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `user_task_definitions` (
`task_key` varchar(255) NOT NULL,
`title` longtext NOT NULL,
`description` longtext NOT NULL,
`target` bigint NOT NULL DEFAULT 0,
`reward_gold` bigint NOT NULL DEFAULT 0,
`action_route` longtext NOT NULL,
`icon_key` longtext NOT NULL,
`sort_order` int NOT NULL DEFAULT 0,
`is_active` tinyint(1) NOT NULL DEFAULT 0,
  PRIMARY KEY (`task_key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `user_task_progress` (
`user_id` char(36) NOT NULL,
`task_key` varchar(255) NOT NULL,
`task_date` date NOT NULL,
`progress` bigint NOT NULL DEFAULT 0,
`completed_at` timestamp NULL DEFAULT NULL,
`claimed_at` timestamp NULL DEFAULT NULL,
`created_at` timestamp NOT NULL,
`updated_at` timestamp NOT NULL,
  PRIMARY KEY (`user_id`, `task_key`, `task_date`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `user_task_reward_ledger` (
`id` char(36) NOT NULL,
`user_id` char(36) NOT NULL,
`task_key` longtext NOT NULL,
`reward_date` date NOT NULL,
`amount` bigint NOT NULL DEFAULT 0,
`reward_type` longtext NOT NULL,
`created_at` timestamp NOT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_user_task_reward_ledger_user_id` (`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `user_daily_login_rewards` (
`user_id` char(36) NOT NULL,
`claim_date` date NOT NULL,
`cycle_day` int NOT NULL DEFAULT 0,
`amount` bigint NOT NULL DEFAULT 0,
`created_at` timestamp NOT NULL,
  PRIMARY KEY (`user_id`, `claim_date`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `saki_gold_reel_spins` (
`id` bigint NOT NULL AUTO_INCREMENT,
`room_id` char(36) NOT NULL,
`user_id` char(36) NOT NULL,
`wager` bigint NOT NULL DEFAULT 0,
`symbols` longtext NOT NULL,
`payout` bigint NOT NULL DEFAULT 0,
`created_at` timestamp NOT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_saki_gold_reel_spins_room_id` (`room_id`),
  KEY `idx_saki_gold_reel_spins_user_id` (`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `saki_redeem_codes` (
`id` char(36) NOT NULL,
`code` varchar(255) NOT NULL,
`expires_at` timestamp NOT NULL,
`max_uses` int NOT NULL DEFAULT 0,
`used_count` int NOT NULL DEFAULT 0,
`is_active` tinyint(1) NOT NULL DEFAULT 0,
`created_by` char(36) NOT NULL,
`created_at` timestamp NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_saki_redeem_codes_code` (`code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `saki_redeem_code_rewards` (
`id` char(36) NOT NULL,
`code_id` char(36) NOT NULL,
`reward_type` longtext NOT NULL,
`item_id` char(36) NULL DEFAULT NULL,
`quantity` bigint NOT NULL DEFAULT 0,
`duration_days` int NULL DEFAULT NULL,
`vip_level` int NULL DEFAULT NULL,
`wealth_level` int NULL DEFAULT NULL,
`created_at` timestamp NOT NULL,
`store_product_id` char(36) NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_saki_redeem_code_rewards_code_id` (`code_id`),
  KEY `idx_saki_redeem_code_rewards_item_id` (`item_id`),
  KEY `idx_saki_redeem_code_rewards_store_product_id` (`store_product_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `saki_redeem_code_uses` (
`id` char(36) NOT NULL,
`code_id` char(36) NOT NULL,
`user_id` char(36) NOT NULL,
`redeemed_at` timestamp NOT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_saki_redeem_code_uses_code_id` (`code_id`),
  KEY `idx_saki_redeem_code_uses_user_id` (`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `saki_slot_spins` (
`id` bigint NOT NULL AUTO_INCREMENT,
`room_id` char(36) NOT NULL,
`user_id` char(36) NOT NULL,
`wager` bigint NOT NULL DEFAULT 0,
`symbols` longtext NOT NULL,
`payout` bigint NOT NULL DEFAULT 0,
`created_at` timestamp NOT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_saki_slot_spins_room_id` (`room_id`),
  KEY `idx_saki_slot_spins_user_id` (`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `room_luck_bags` (
`id` char(36) NOT NULL,
`room_id` char(36) NOT NULL,
`sender_id` char(36) NOT NULL,
`total_gold` bigint NOT NULL DEFAULT 0,
`recipient_limit` int NOT NULL DEFAULT 0,
`claimed_count` int NOT NULL DEFAULT 0,
`remaining_gold` bigint NOT NULL DEFAULT 0,
`status` varchar(255) NOT NULL,
`created_at` timestamp NOT NULL,
`expires_at` timestamp NOT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_room_luck_bags_room_id` (`room_id`),
  KEY `idx_room_luck_bags_sender_id` (`sender_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `room_luck_bag_claims` (
`id` char(36) NOT NULL,
`bag_id` char(36) NOT NULL,
`user_id` char(36) NOT NULL,
`amount_gold` bigint NOT NULL DEFAULT 0,
`claimed_at` timestamp NOT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_room_luck_bag_claims_bag_id` (`bag_id`),
  KEY `idx_room_luck_bag_claims_user_id` (`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `message_reactions` (
`id` char(36) NOT NULL,
`message_id` char(36) NOT NULL,
`conversation_id` char(36) NOT NULL,
`user_id` char(36) NOT NULL,
`emoji` longtext NOT NULL,
`created_at` timestamp NOT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_message_reactions_message_id` (`message_id`),
  KEY `idx_message_reactions_conversation_id` (`conversation_id`),
  KEY `idx_message_reactions_user_id` (`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `badge_catalog` (
`badge_key` varchar(255) NOT NULL,
`name` longtext NOT NULL,
`description` longtext NOT NULL,
`category` longtext NOT NULL,
`target` bigint NOT NULL DEFAULT 0,
`asset_path` longtext NOT NULL,
`sort_order` int NOT NULL DEFAULT 0,
`is_active` tinyint(1) NOT NULL DEFAULT 0,
`created_at` timestamp NOT NULL,
  PRIMARY KEY (`badge_key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `user_badges` (
`user_id` char(36) NOT NULL,
`badge_key` varchar(255) NOT NULL,
`earned_at` timestamp NOT NULL,
  PRIMARY KEY (`user_id`, `badge_key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `room_seat_sessions` (
`id` char(36) NOT NULL,
`user_id` char(36) NOT NULL,
`room_id` char(36) NOT NULL,
`started_at` timestamp NOT NULL,
`ended_at` timestamp NOT NULL,
`duration_seconds` bigint NOT NULL DEFAULT 0,
`created_at` timestamp NOT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_room_seat_sessions_user_id` (`user_id`),
  KEY `idx_room_seat_sessions_room_id` (`room_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `room_playlist` (
`id` char(36) NOT NULL,
`room_id` char(36) NOT NULL,
`track_id` char(36) NOT NULL,
`added_by` char(36) NOT NULL,
`position` int NOT NULL DEFAULT 0,
`created_at` timestamp NOT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_room_playlist_room_id` (`room_id`),
  KEY `idx_room_playlist_track_id` (`track_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `admin_role_permissions` (
`role` varchar(255) NOT NULL,
`permission` varchar(255) NOT NULL,
`created_at` timestamp NOT NULL,
  PRIMARY KEY (`role`, `permission`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `admin_audit_log` (
`id` char(36) NOT NULL,
`actor_id` char(36) NOT NULL,
`action` longtext NOT NULL,
`target_user_id` char(36) NULL DEFAULT NULL,
`metadata` longtext NOT NULL,
`created_at` timestamp NOT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_admin_audit_log_actor_id` (`actor_id`),
  KEY `idx_admin_audit_log_target_user_id` (`target_user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `host_agency_payout_requests` (
`id` char(36) NOT NULL,
`agency_id` char(36) NOT NULL,
`host_id` char(36) NOT NULL,
`diamonds` bigint NOT NULL DEFAULT 0,
`usd_amount` decimal(20,6) NOT NULL DEFAULT 0,
`status` varchar(255) NOT NULL,
`created_at` timestamp NOT NULL,
`reviewed_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_host_agency_payout_requests_agency_id` (`agency_id`),
  KEY `idx_host_agency_payout_requests_host_id` (`host_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `host_agency_wallets` (
`user_id` char(36) NOT NULL,
`usd_balance` decimal(20,6) NOT NULL DEFAULT 0,
`usd_reserved` decimal(20,6) NOT NULL DEFAULT 0,
`total_usd_earned` decimal(20,6) NOT NULL DEFAULT 0,
`total_usd_withdrawn` decimal(20,6) NOT NULL DEFAULT 0,
`created_at` timestamp NOT NULL,
`updated_at` timestamp NOT NULL,
  PRIMARY KEY (`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `host_agency_wallet_transactions` (
`id` char(36) NOT NULL,
`user_id` char(36) NOT NULL,
`transaction_type` longtext NOT NULL,
`diamonds` bigint NOT NULL DEFAULT 0,
`usd_amount` decimal(20,6) NOT NULL DEFAULT 0,
`gold_coins` bigint NOT NULL DEFAULT 0,
`metadata` longtext NOT NULL,
`created_at` timestamp NOT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_host_agency_wallet_transactions_user_id` (`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `host_agency_withdrawal_requests` (
`id` char(36) NOT NULL,
`agency_id` char(36) NOT NULL,
`user_id` char(36) NOT NULL,
`usd_amount` decimal(20,6) NOT NULL DEFAULT 0,
`channel` longtext NOT NULL,
`status` varchar(255) NOT NULL,
`created_at` timestamp NOT NULL,
`reviewed_at` timestamp NULL DEFAULT NULL,
`metadata` longtext NOT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_host_agency_withdrawal_requests_agency_id` (`agency_id`),
  KEY `idx_host_agency_withdrawal_requests_user_id` (`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `shipping_agents` (
`user_id` char(36) NOT NULL,
`is_active` tinyint(1) NOT NULL DEFAULT 0,
`saki_coins` bigint NOT NULL DEFAULT 0,
`assigned_by` char(36) NULL DEFAULT NULL,
`assigned_at` timestamp NOT NULL,
`updated_at` timestamp NOT NULL,
  PRIMARY KEY (`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `shipping_transactions` (
`id` char(36) NOT NULL,
`agent_id` char(36) NOT NULL,
`recipient_id` char(36) NOT NULL,
`saki_coins` bigint NOT NULL DEFAULT 0,
`gold_coins` bigint NOT NULL DEFAULT 0,
`created_at` timestamp NOT NULL,
`metadata` longtext NOT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_shipping_transactions_agent_id` (`agent_id`),
  KEY `idx_shipping_transactions_recipient_id` (`recipient_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `saki_buffet_rounds` (
`id` bigint NOT NULL AUTO_INCREMENT,
`room_id` char(36) NOT NULL,
`round_number` bigint NOT NULL DEFAULT 0,
`status` varchar(255) NOT NULL,
`started_at` timestamp NOT NULL,
`betting_ends_at` timestamp NOT NULL,
`winner_food_id` longtext NULL DEFAULT NULL,
`resolved_at` timestamp NULL DEFAULT NULL,
`created_at` timestamp NOT NULL,
`spinning_started_at` timestamp NULL DEFAULT NULL,
`result_shown_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_saki_buffet_rounds_room_id` (`room_id`),
  KEY `idx_saki_buffet_rounds_winner_food_id` (`winner_food_id`(36))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `saki_buffet_bets` (
`id` bigint NOT NULL AUTO_INCREMENT,
`round_id` bigint NOT NULL DEFAULT 0,
`room_id` char(36) NOT NULL,
`user_id` char(36) NOT NULL,
`food_id` longtext NOT NULL,
`amount` bigint NOT NULL DEFAULT 0,
`payout` bigint NOT NULL DEFAULT 0,
`created_at` timestamp NOT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_saki_buffet_bets_round_id` (`round_id`),
  KEY `idx_saki_buffet_bets_room_id` (`room_id`),
  KEY `idx_saki_buffet_bets_user_id` (`user_id`),
  KEY `idx_saki_buffet_bets_food_id` (`food_id`(36))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `room_cinema_state` (
`room_id` char(36) NOT NULL,
`video_id` varchar(255) NULL DEFAULT NULL,
`video_title` longtext NULL DEFAULT NULL,
`is_playing` tinyint(1) NOT NULL DEFAULT 0,
`position_seconds` longtext NOT NULL,
`volume` longtext NOT NULL,
`changed_by` char(36) NULL DEFAULT NULL,
`changed_at` timestamp NOT NULL,
  PRIMARY KEY (`room_id`),
  KEY `idx_room_cinema_state_video_id` (`video_id`(36))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `verified_gold_recharge_events` (
`id` char(36) NOT NULL,
`user_id` char(36) NOT NULL,
`gold_coins` bigint NOT NULL DEFAULT 0,
`source` longtext NOT NULL,
`provider_transaction_id` varchar(255) NULL DEFAULT NULL,
`verified` tinyint(1) NOT NULL DEFAULT 0,
`metadata` longtext NOT NULL,
`created_at` timestamp NOT NULL,
`verified_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_verified_gold_recharge_events_user_id` (`user_id`),
  KEY `idx_verified_gold_recharge_events_provider_transaction_id` (`provider_transaction_id`(36))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `luck_daily_settings` (
`luck_date` date NOT NULL,
`win_percent` longtext NOT NULL,
`updated_at` timestamp NOT NULL,
  PRIMARY KEY (`luck_date`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `auth_users` (id char(36) NOT NULL, email varchar(255) NULL, username varchar(120) NOT NULL, password_hash varchar(255) NOT NULL, google_subject varchar(255) NULL UNIQUE, google_email varchar(255) NULL, is_active tinyint(1) NOT NULL DEFAULT 1, created_at timestamp NOT NULL DEFAULT current_timestamp(), PRIMARY KEY(id), UNIQUE KEY uq_auth_username(username), UNIQUE KEY uq_auth_email(email)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `auth_sessions` (id bigint NOT NULL AUTO_INCREMENT, user_id char(36) NOT NULL, token_hash char(64) NOT NULL, expires_at timestamp NOT NULL, last_used_at timestamp NOT NULL DEFAULT current_timestamp(), user_agent varchar(255) NULL, ip_address varchar(64) NULL, PRIMARY KEY(id), UNIQUE KEY uq_auth_token(token_hash), KEY idx_auth_session_user(user_id)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

SET FOREIGN_KEY_CHECKS=1;
