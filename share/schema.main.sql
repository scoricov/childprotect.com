# **************************************** #
#                                          #
#   childprotect.com main database schema  #
#                                          #
# **************************************** #

DROP TABLE IF EXISTS `token_deleted`;
DROP TABLE IF EXISTS `token`;
DROP TABLE IF EXISTS `user_confirm`;
DROP TABLE IF EXISTS `user`;

CREATE TABLE `user` (
  id                 INT UNSIGNED AUTO_INCREMENT not null,
  email              VARCHAR(255) NOT NULL,
  pwd                BINARY(16),
  name               VARCHAR(255),
  url                VARCHAR(255) NOT NULL,
  flag               tinyint unsigned NOT NULL DEFAULT 0,
  api_key            CHAR(16) NOT NULL,
  tokens_submitted   INT UNSIGNED NOT NULL DEFAULT 0,
  tokens_deleted     INT UNSIGNED NOT NULL DEFAULT 0,
  last_login_time    datetime default null,
  last_login_host    VARCHAR(255) default null,
  created_time       datetime DEFAULT NULL,
  modified_time      datetime DEFAULT NULL,
  deleted            tinyint UNSIGNED DEFAULT 0,
  PRIMARY KEY(id),
  INDEX(email),
  INDEX(deleted)
) ENGINE=InnoDB CHARACTER SET utf8 COLLATE utf8_general_ci;

CREATE TABLE `user_confirm` (
  `user_id`          int unsigned not null,
  `action`           tinyint unsigned not null default 0,
  `hash`             BINARY(16) not null,
  `created_time`     datetime NOT NULL,
  PRIMARY KEY(`user_id`, `action`),
  FOREIGN KEY(`user_id`) REFERENCES `user`(`id`) ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE `token` (
  id                 INT UNSIGNED AUTO_INCREMENT NOT NULL,
  footprint          BINARY(24) NOT NULL,
  submitted          DATE NOT NULL,
  user_id            INT UNSIGNED NOT NULL,
  PRIMARY KEY(id),
  UNIQUE INDEX(footprint),
  INDEX(submitted),
  FOREIGN KEY(`user_id`) REFERENCES `user`(`id`) ON UPDATE RESTRICT ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE `token_deleted` (
  token_id           INT UNSIGNED NOT NULL,
  user_id            INT UNSIGNED NOT NULL,
  deleted            DATE NOT NULL,
  PRIMARY KEY(token_id, user_id),
  FOREIGN KEY(`token_id`) REFERENCES `token`(`id`) ON UPDATE RESTRICT ON DELETE CASCADE,
  FOREIGN KEY(`user_id`) REFERENCES `user`(`id`) ON UPDATE RESTRICT ON DELETE CASCADE
) ENGINE=InnoDB;
