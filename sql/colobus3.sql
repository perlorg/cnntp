-- MySQL dump 10.11
--
-- Host: localhost    Database: colobus3
-- ------------------------------------------------------
-- Server version	5.0.51a-community-log

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `articles`
--

DROP TABLE IF EXISTS `articles`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `articles` (
  `group_id` smallint(5) unsigned NOT NULL default '0',
  `id` int(10) unsigned NOT NULL default '0',
  `msgid` varchar(32) NOT NULL default '',
  `subjhash` varchar(32) NOT NULL default '',
  `fromhash` varchar(32) NOT NULL default '',
  `thread_id` int(10) unsigned NOT NULL default '0',
  `parent` int(10) unsigned NOT NULL default '0',
  `received` datetime NOT NULL default '0000-00-00 00:00:00',
  `h_date` varchar(255) NOT NULL default '',
  `h_messageid` varchar(255) NOT NULL default '',
  `h_from` varchar(255) NOT NULL default '',
  `h_subject` varchar(255) NOT NULL default '',
  `h_references` varchar(255) NOT NULL default '',
  `h_lines` mediumint(8) unsigned NOT NULL default '0',
  `h_bytes` int(10) unsigned NOT NULL default '0',
  PRIMARY KEY  (`group_id`,`id`),
  KEY `msgid` (`msgid`),
  KEY `fromhash` (`fromhash`),
  KEY `grp` (`group_id`,`received`),
  KEY `grp_2` (`group_id`,`thread_id`,`parent`),
  KEY `grp_3` (`group_id`,`subjhash`),
  KEY `subjhash` (`subjhash`,`received`),
  CONSTRAINT `articles_ibfk_1` FOREIGN KEY (`group_id`) REFERENCES `groups` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `groups`
--

DROP TABLE IF EXISTS `groups`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `groups` (
  `id` smallint(5) unsigned NOT NULL,
  `name` varchar(255) NOT NULL,
  `description` varchar(255) NOT NULL,
  PRIMARY KEY  (`id`),
  UNIQUE KEY `name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
SET character_set_client = @saved_cs_client;

/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2008-10-26 19:57:18
