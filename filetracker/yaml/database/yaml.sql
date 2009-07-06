-- MySQL dump 10.13  Distrib 5.1.35, for Win32 (ia32)
--
-- Host: localhost    Database: yaml
-- ------------------------------------------------------
-- Server version	5.1.35-community

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
-- Table structure for table `filecontents`
--

DROP TABLE IF EXISTS `filecontents`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `filecontents` (
  `filecontent_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `identifier` varchar(1024) DEFAULT NULL,
  `size` int(255) unsigned NOT NULL,
  PRIMARY KEY (`filecontent_id`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;


--
-- Table structure for table `filewithname`
--

DROP TABLE IF EXISTS `filewithname`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `filewithname` (
  `filewithname_id` int(10) unsigned NOT NULL,
  `filecontent_id` int(10) unsigned NOT NULL,
  `code_basename` varchar(1024) NOT NULL,
  `directory` varchar(1024) NOT NULL,
  `ctime` datetime NOT NULL,
  `mtime` datetime NOT NULL,
  PRIMARY KEY (`filewithname_id`),
  KEY `filecontent_id` (`filecontent_id`),
  CONSTRAINT `filecontent_id` FOREIGN KEY (`filecontent_id`) REFERENCES `filecontents` (`filecontent_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `parameters`
--

DROP TABLE IF EXISTS `parameters`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `parameters` (
  `parameter_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `code_key` varchar(1024) NOT NULL,
  `code_value` varchar(1024) NOT NULL,
  `run_id` int(10) unsigned NOT NULL,
  PRIMARY KEY (`parameter_id`),
  KEY `run_id` (`run_id`),
  CONSTRAINT `run_id3` FOREIGN KEY (`run_id`) REFERENCES `runs` (`run_id`)
) ENGINE=InnoDB AUTO_INCREMENT=494 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `run_filewithname`
--

DROP TABLE IF EXISTS `run_filewithname`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `run_filewithname` (
  `run_id` int(10) unsigned NOT NULL,
  `filewithname_id` int(10) unsigned NOT NULL,
  `input_file` tinyint(1) NOT NULL,
  KEY `run_id` (`run_id`),
  KEY `filewithname` (`filewithname_id`),
  CONSTRAINT `filewithname_id` FOREIGN KEY (`filewithname_id`) REFERENCES `filewithname` (`filewithname_id`),
  CONSTRAINT `run_id2` FOREIGN KEY (`run_id`) REFERENCES `runs` (`run_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `runs`
--

DROP TABLE IF EXISTS `runs`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `runs` (
  `run_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `user` varchar(1024) NOT NULL,
  `title` varchar(1024) NOT NULL,
  `host` varchar(1024) NOT NULL,
  `script_uri` varchar(1024) NOT NULL,
  `version` varchar(1024) NOT NULL,
  `start_time` datetime NOT NULL,
  `end_time` datetime NOT NULL,
  PRIMARY KEY (`run_id`)
) ENGINE=InnoDB AUTO_INCREMENT=42 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

