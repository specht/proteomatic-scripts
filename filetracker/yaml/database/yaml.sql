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
  `identifier` tinyint(1) NOT NULL,
  `size` int(45) unsigned NOT NULL,
  PRIMARY KEY (`filecontent_id`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `filecontents`
--

LOCK TABLES `filecontents` WRITE;
/*!40000 ALTER TABLE `filecontents` DISABLE KEYS */;
/*!40000 ALTER TABLE `filecontents` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `filewithname`
--

DROP TABLE IF EXISTS `filewithname`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `filewithname` (
  `filewithname_id` int(10) unsigned NOT NULL,
  `filecontent_id` int(10) unsigned NOT NULL,
  `basename` varchar(45) NOT NULL,
  `directory` varchar(45) NOT NULL,
  `ctime` datetime NOT NULL,
  `mtime` datetime NOT NULL,
  PRIMARY KEY (`filewithname_id`),
  KEY `filecontent_id` (`filecontent_id`),
  CONSTRAINT `filecontent_id` FOREIGN KEY (`filecontent_id`) REFERENCES `filecontents` (`filecontent_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `filewithname`
--

LOCK TABLES `filewithname` WRITE;
/*!40000 ALTER TABLE `filewithname` DISABLE KEYS */;
/*!40000 ALTER TABLE `filewithname` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `parameters`
--

DROP TABLE IF EXISTS `parameters`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `parameters` (
  `parameter_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `key` varchar(45) NOT NULL,
  `value` tinyint(1) NOT NULL,
  `run_id` int(10) unsigned NOT NULL,
  PRIMARY KEY (`parameter_id`) USING BTREE,
  KEY `run_id` (`run_id`),
  CONSTRAINT `run_id3` FOREIGN KEY (`run_id`) REFERENCES `runs` (`run_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `parameters`
--

LOCK TABLES `parameters` WRITE;
/*!40000 ALTER TABLE `parameters` DISABLE KEYS */;
/*!40000 ALTER TABLE `parameters` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `run_filecontents`
--

DROP TABLE IF EXISTS `run_filecontents`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `run_filecontents` (
  `run_id` int(10) unsigned NOT NULL,
  `filecontent_id` int(10) unsigned NOT NULL,
  `input_file` tinyint(1) NOT NULL,
  KEY `filecontent_id` (`filecontent_id`) USING BTREE,
  KEY `run_id` (`run_id`),
  CONSTRAINT `filecontent_id2` FOREIGN KEY (`filecontent_id`) REFERENCES `filecontents` (`filecontent_id`),
  CONSTRAINT `run_id2` FOREIGN KEY (`run_id`) REFERENCES `runs` (`run_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `run_filecontents`
--

LOCK TABLES `run_filecontents` WRITE;
/*!40000 ALTER TABLE `run_filecontents` DISABLE KEYS */;
/*!40000 ALTER TABLE `run_filecontents` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `runs`
--

DROP TABLE IF EXISTS `runs`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `runs` (
  `run_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `user` varchar(20) NOT NULL,
  `title` varchar(45) NOT NULL,
  `host` varchar(15) NOT NULL,
  PRIMARY KEY (`run_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `runs`
--

LOCK TABLES `runs` WRITE;
/*!40000 ALTER TABLE `runs` DISABLE KEYS */;
/*!40000 ALTER TABLE `runs` ENABLE KEYS */;
UNLOCK TABLES;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2009-06-24 11:54:14
