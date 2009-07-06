-- phpMyAdmin SQL Dump
-- version 2.11.3deb1ubuntu1.1
-- http://www.phpmyadmin.net
--
-- Host: localhost
-- Generation Time: Jul 06, 2009 at 01:45 PM
-- Server version: 5.0.51
-- PHP Version: 5.2.4-2ubuntu5.6

SET SQL_MODE="NO_AUTO_VALUE_ON_ZERO";

--
-- Database: `filetracker`
--

-- --------------------------------------------------------

--
-- Table structure for table `filecontents`
--

CREATE TABLE IF NOT EXISTS `filecontents` (
  `filecontent_id` int(10) unsigned NOT NULL auto_increment,
  `identifier` varchar(1024) default NULL,
  `size` int(255) unsigned NOT NULL,
  PRIMARY KEY  (`filecontent_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1 AUTO_INCREMENT=1 ;

-- --------------------------------------------------------

--
-- Table structure for table `filewithname`
--

CREATE TABLE IF NOT EXISTS `filewithname` (
  `filewithname_id` int(10) unsigned NOT NULL auto_increment,
  `filecontent_id` int(10) unsigned NOT NULL,
  `code_basename` varchar(1024) NOT NULL,
  `directory` varchar(1024) NOT NULL,
  `ctime` datetime NOT NULL,
  `mtime` datetime NOT NULL,
  PRIMARY KEY  (`filewithname_id`),
  KEY `filecontent_id` (`filecontent_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1 AUTO_INCREMENT=1 ;

-- --------------------------------------------------------

--
-- Table structure for table `parameters`
--

CREATE TABLE IF NOT EXISTS `parameters` (
  `parameter_id` int(10) unsigned NOT NULL auto_increment,
  `code_key` varchar(1024) NOT NULL,
  `code_value` varchar(1024) NOT NULL,
  `run_id` int(10) unsigned NOT NULL,
  PRIMARY KEY  (`parameter_id`),
  KEY `run_id` (`run_id`)
) ENGINE=InnoDB  DEFAULT CHARSET=latin1 AUTO_INCREMENT=494 ;

-- --------------------------------------------------------

--
-- Table structure for table `runs`
--

CREATE TABLE IF NOT EXISTS `runs` (
  `run_id` int(10) unsigned NOT NULL auto_increment,
  `user` varchar(1024) NOT NULL,
  `title` varchar(1024) NOT NULL,
  `host` varchar(1024) NOT NULL,
  `script_uri` varchar(1024) NOT NULL,
  `version` varchar(1024) NOT NULL,
  `start_time` datetime NOT NULL,
  `end_time` datetime NOT NULL,
  PRIMARY KEY  (`run_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1 AUTO_INCREMENT=1 ;

-- --------------------------------------------------------

--
-- Table structure for table `run_filewithname`
--

CREATE TABLE IF NOT EXISTS `run_filewithname` (
  `run_id` int(10) unsigned NOT NULL,
  `filewithname_id` int(10) unsigned NOT NULL,
  `input_file` tinyint(1) NOT NULL,
  KEY `run_id` (`run_id`),
  KEY `filewithname` (`filewithname_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Constraints for dumped tables
--

--
-- Constraints for table `filewithname`
--
ALTER TABLE `filewithname`
  ADD CONSTRAINT `filecontent_id` FOREIGN KEY (`filecontent_id`) REFERENCES `filecontents` (`filecontent_id`);

--
-- Constraints for table `parameters`
--
ALTER TABLE `parameters`
  ADD CONSTRAINT `run_id3` FOREIGN KEY (`run_id`) REFERENCES `runs` (`run_id`);

--
-- Constraints for table `run_filewithname`
--
ALTER TABLE `run_filewithname`
  ADD CONSTRAINT `filewithname_id` FOREIGN KEY (`filewithname_id`) REFERENCES `filewithname` (`filewithname_id`),
  ADD CONSTRAINT `run_id2` FOREIGN KEY (`run_id`) REFERENCES `runs` (`run_id`);
