-- phpMyAdmin SQL Dump
-- version 5.2.1
-- https://www.phpmyadmin.net/
--
-- Host: 127.0.0.1:3307
-- Generation Time: May 18, 2026 at 04:24 PM
-- Server version: 10.4.32-MariaDB
-- PHP Version: 8.0.30

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Database: `attendx`
--

-- --------------------------------------------------------

--
-- Table structure for table `attendance_records`
--

CREATE TABLE `attendance_records` (
  `id` varchar(36) NOT NULL,
  `session_id` varchar(36) NOT NULL,
  `student_id` varchar(36) NOT NULL,
  `status` enum('present','absent','late') NOT NULL DEFAULT 'present',
  `submission_method` enum('app','manual') NOT NULL DEFAULT 'app',
  `geofence_passed` tinyint(1) NOT NULL DEFAULT 1,
  `latitude` decimal(10,7) DEFAULT NULL,
  `longitude` decimal(10,7) DEFAULT NULL,
  `distance_m` decimal(8,2) DEFAULT NULL,
  `marked_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `attendance_sessions`
--

CREATE TABLE `attendance_sessions` (
  `id` varchar(36) NOT NULL,
  `session_code` varchar(10) NOT NULL,
  `course_id` varchar(36) NOT NULL,
  `classroom_id` varchar(36) NOT NULL,
  `lecturer_id` varchar(36) NOT NULL,
  `status` enum('active','closed') NOT NULL DEFAULT 'active',
  `checkin_open` tinyint(1) NOT NULL DEFAULT 1,
  `started_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `closed_at` timestamp NULL DEFAULT NULL,
  `expires_at` datetime DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `attendance_sessions`
--

INSERT INTO `attendance_sessions` (`id`, `session_code`, `course_id`, `classroom_id`, `lecturer_id`, `status`, `checkin_open`, `started_at`, `closed_at`, `expires_at`) VALUES
('74d478ad-6c78-4b73-bc53-d7cac00f6cb0', '6BRJAW', '4da7026d-6312-46ca-b8d1-e6a876567d50', 'a9a8f745-03fe-49e1-be46-698d70021d54', 'e1d71245-2709-4d3b-89f0-cdbd5baf18c5', 'active', 1, '2026-05-18 08:31:57', NULL, '2026-05-18 10:01:57');

-- --------------------------------------------------------

--
-- Table structure for table `classrooms`
--

CREATE TABLE `classrooms` (
  `id` varchar(36) NOT NULL,
  `name` varchar(100) NOT NULL,
  `building` varchar(100) DEFAULT NULL,
  `capacity` int(11) NOT NULL DEFAULT 60,
  `latitude` decimal(10,7) NOT NULL,
  `longitude` decimal(10,7) NOT NULL,
  `radius_m` int(11) NOT NULL DEFAULT 30,
  `is_active` tinyint(1) NOT NULL DEFAULT 1,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `classrooms`
--

INSERT INTO `classrooms` (`id`, `name`, `building`, `capacity`, `latitude`, `longitude`, `radius_m`, `is_active`, `created_at`) VALUES
('45beb2b8-40ee-4ba2-8999-7c590ea4805d', 'R-102', 'Main Block', 40, -1.9435000, 30.0615000, 20, 1, '2026-05-18 07:08:30'),
('770dfa68-45aa-4feb-a16d-8b10be588c19', 'LT-3', 'Engineering Block B', 80, -1.9441000, 30.0619000, 30, 1, '2026-05-18 07:08:30'),
('a24ed6b6-cb76-4da0-bbd4-f070296aaffb', 'LT-2', 'Engineering Block A', 60, -1.9448000, 30.0622000, 30, 1, '2026-05-18 07:08:30'),
('a9a8f745-03fe-49e1-be46-698d70021d54', 'LT-1', 'Engineering Block A', 60, -1.9450000, 30.0625000, 30, 1, '2026-05-18 07:08:30'),
('cf2d0e16-5c1b-4d31-b7c3-694743061054', 'LT-5', 'Science Block', 50, -1.9460000, 30.0630000, 25, 1, '2026-05-18 07:08:30');

-- --------------------------------------------------------

--
-- Table structure for table `courses`
--

CREATE TABLE `courses` (
  `id` varchar(36) NOT NULL,
  `code` varchar(20) NOT NULL,
  `name` varchar(255) NOT NULL,
  `credits` int(11) NOT NULL DEFAULT 3,
  `department` varchar(100) DEFAULT NULL,
  `lecturer_id` varchar(36) DEFAULT NULL,
  `is_active` tinyint(1) NOT NULL DEFAULT 1,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `courses`
--

INSERT INTO `courses` (`id`, `code`, `name`, `credits`, `department`, `lecturer_id`, `is_active`, `created_at`) VALUES
('183d41d7-0a02-4f37-9643-1a6c5929285f', 'CS401', 'Software Engineering', 3, 'Computer Science', NULL, 1, '2026-05-18 07:08:30'),
('4da7026d-6312-46ca-b8d1-e6a876567d50', 'CS201', 'Data Structures', 3, 'Computer Science', 'e1d71245-2709-4d3b-89f0-cdbd5baf18c5', 1, '2026-05-18 07:08:30'),
('98d93687-bf03-42b6-b93c-821c3ce17e7c', 'CS301', 'Advanced Databases', 3, 'Computer Science', 'e1d71245-2709-4d3b-89f0-cdbd5baf18c5', 1, '2026-05-18 07:08:30'),
('9dd05ecb-8101-4ea6-a12e-564237ccb76e', 'CS350', 'Computer Networks', 3, 'Computer Science', 'a96a00af-db35-4808-8fd1-d3c8ccdfa7a8', 1, '2026-05-18 07:08:30'),
('bf5d9a68-3dc2-48c9-9af1-a1c97f2872e7', 'MATH301', 'Numerical Methods', 2, 'Mathematics', 'a96a00af-db35-4808-8fd1-d3c8ccdfa7a8', 1, '2026-05-18 07:08:30');

-- --------------------------------------------------------

--
-- Table structure for table `device_tokens`
--

CREATE TABLE `device_tokens` (
  `id` varchar(36) NOT NULL,
  `user_id` varchar(36) NOT NULL,
  `token` text NOT NULL,
  `platform` enum('android','ios','web') NOT NULL DEFAULT 'android',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `enrollments`
--

CREATE TABLE `enrollments` (
  `id` varchar(36) NOT NULL,
  `student_id` varchar(36) NOT NULL,
  `course_id` varchar(36) NOT NULL,
  `enrolled_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `enrollments`
--

INSERT INTO `enrollments` (`id`, `student_id`, `course_id`, `enrolled_at`) VALUES
('1e324d85-f40a-462d-a95f-a622b29746ac', 'a90b9218-39e4-4956-8461-1454c5b08e79', '98d93687-bf03-42b6-b93c-821c3ce17e7c', '2026-05-18 07:08:30'),
('27350788-6336-4216-b853-e00959af0ceb', 'e31712c1-31b0-4e08-bd4b-57ded44b7f1a', '9dd05ecb-8101-4ea6-a12e-564237ccb76e', '2026-05-18 07:08:30'),
('28c123eb-8d8a-47b6-9aeb-9a87eec9e1ec', 'e31712c1-31b0-4e08-bd4b-57ded44b7f1a', '98d93687-bf03-42b6-b93c-821c3ce17e7c', '2026-05-18 07:08:30'),
('2e8dd2c8-2a21-4a3f-87f4-24e094e3d2bc', 'fbb4f2cf-5882-4af4-aef0-4c2511abac82', '98d93687-bf03-42b6-b93c-821c3ce17e7c', '2026-05-18 07:08:30'),
('5410f54a-b3c9-411f-a841-2e2744cb4d35', 'fb4e8926-e40f-4afa-af86-418e041830aa', '4da7026d-6312-46ca-b8d1-e6a876567d50', '2026-05-18 07:08:30'),
('756d6e97-1157-43da-ba49-b50cfd93c95e', 'fb4e8926-e40f-4afa-af86-418e041830aa', '98d93687-bf03-42b6-b93c-821c3ce17e7c', '2026-05-18 07:08:30'),
('7728b84e-9b32-4634-b7d6-63fb5e4cf4a0', '34dd7b87-b27b-4df2-a369-8efc52fff6b9', '4da7026d-6312-46ca-b8d1-e6a876567d50', '2026-05-18 07:08:30'),
('80972c45-9c10-4bf1-8e9d-efb2cbe07020', '266e8693-1e0f-4fe3-b671-9ced002ba333', 'bf5d9a68-3dc2-48c9-9af1-a1c97f2872e7', '2026-05-18 07:08:30'),
('8316a772-0cf7-48bd-8760-3cc2d50ffd58', '266e8693-1e0f-4fe3-b671-9ced002ba333', '183d41d7-0a02-4f37-9643-1a6c5929285f', '2026-05-18 07:08:30'),
('8fb1d7b6-57b2-4332-a3d3-857378fdcf81', 'fb4e8926-e40f-4afa-af86-418e041830aa', '9dd05ecb-8101-4ea6-a12e-564237ccb76e', '2026-05-18 07:08:30'),
('920330de-3dea-4800-8f05-33c3a7dd1055', 'e31712c1-31b0-4e08-bd4b-57ded44b7f1a', '4da7026d-6312-46ca-b8d1-e6a876567d50', '2026-05-18 07:08:30'),
('d03e8036-9a30-4aac-8265-66c4833f7c51', 'e31712c1-31b0-4e08-bd4b-57ded44b7f1a', 'bf5d9a68-3dc2-48c9-9af1-a1c97f2872e7', '2026-05-18 07:08:30'),
('d4938ac6-7cdd-4000-b65f-254d5593fb0e', 'fbb4f2cf-5882-4af4-aef0-4c2511abac82', '4da7026d-6312-46ca-b8d1-e6a876567d50', '2026-05-18 07:08:30'),
('e433bf60-76da-4f2d-81f0-29959ccf730d', 'a90b9218-39e4-4956-8461-1454c5b08e79', '9dd05ecb-8101-4ea6-a12e-564237ccb76e', '2026-05-18 07:08:30'),
('e7325daa-7730-4dc6-bddb-517ba78cbebb', '34dd7b87-b27b-4df2-a369-8efc52fff6b9', '183d41d7-0a02-4f37-9643-1a6c5929285f', '2026-05-18 07:08:30'),
('eb65d48e-ed75-48b4-a60d-6137feb54256', 'e31712c1-31b0-4e08-bd4b-57ded44b7f1a', '183d41d7-0a02-4f37-9643-1a6c5929285f', '2026-05-18 07:08:30');

-- --------------------------------------------------------

--
-- Table structure for table `notifications`
--

CREATE TABLE `notifications` (
  `id` varchar(36) NOT NULL,
  `user_id` varchar(36) NOT NULL,
  `title` varchar(255) NOT NULL,
  `body` text NOT NULL,
  `type` enum('session_started','attendance_confirmed','absence_warning','system') NOT NULL DEFAULT 'system',
  `is_read` tinyint(1) NOT NULL DEFAULT 0,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `notification_preferences`
--

CREATE TABLE `notification_preferences` (
  `user_id` varchar(36) NOT NULL,
  `session_start` tinyint(1) NOT NULL DEFAULT 1,
  `absence_alert` tinyint(1) NOT NULL DEFAULT 1,
  `low_attendance` tinyint(1) NOT NULL DEFAULT 1,
  `weekly_report` tinyint(1) NOT NULL DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `password_reset_tokens`
--

CREATE TABLE `password_reset_tokens` (
  `id` varchar(36) NOT NULL,
  `user_id` varchar(36) NOT NULL,
  `token` varchar(64) NOT NULL,
  `expires_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `refresh_tokens`
--

CREATE TABLE `refresh_tokens` (
  `id` varchar(36) NOT NULL,
  `user_id` varchar(36) NOT NULL,
  `token_hash` varchar(255) NOT NULL,
  `expires_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `refresh_tokens`
--

INSERT INTO `refresh_tokens` (`id`, `user_id`, `token_hash`, `expires_at`, `created_at`) VALUES
('0542bce6-1b34-4f72-8919-a05716047a94', '321fea50-3cc9-462a-87a6-f14aa3f1901a', '$2b$08$hGQmJDXITlrp7s66iRmHCeak5ydMXe60Q/qFXkbC50kVmLYRf0vai', '2026-05-25 06:34:26', '2026-05-18 08:34:26'),
('09585d57-630d-430f-b33d-3fbc7da3a473', '4df044ab-55fb-4dce-8f0a-1aa22e2463a3', '$2b$08$bNwsfpAwFGbDuPztMTD3UesILWcYyq6dKmSFffhot70cmc3OCnskm', '2026-05-25 10:17:25', '2026-05-18 12:17:25'),
('0b228728-15ba-4af2-9f55-3f075a732fb8', '321fea50-3cc9-462a-87a6-f14aa3f1901a', '$2b$08$6qDqUaUZccfti1hkJJSO8uQqgAr44X50i0EW8IcTscr/AX9fldkGK', '2026-05-25 11:42:10', '2026-05-18 13:42:10'),
('1801c27f-c7a5-49fd-8ea3-24c10c26b632', '4df044ab-55fb-4dce-8f0a-1aa22e2463a3', '$2b$08$hsNLDViJEEhC1nK/HrGtne51rm3dae28PWozlZR5pquoODym0/EUC', '2026-05-25 10:32:06', '2026-05-18 12:32:06'),
('20a9c5a9-f978-4a4d-b770-9ff3e9c74c3e', '4df044ab-55fb-4dce-8f0a-1aa22e2463a3', '$2b$08$1beCKGNDMS4LswgX2qm6Guab8ztdbz8ByHuu1ZEtfvvyLX84pA4JW', '2026-05-25 10:21:48', '2026-05-18 12:21:48'),
('266a4126-72d8-43d5-87f2-692501b2dae7', '4df044ab-55fb-4dce-8f0a-1aa22e2463a3', '$2b$08$V9n5wYM.X9gOLa3QMLzo5.XFRLZtyRAP/.awpKD3eBJHAo1iJgdWa', '2026-05-25 10:21:53', '2026-05-18 12:21:53'),
('2edd16b8-6587-4b74-8064-62afc7274aaa', '4df044ab-55fb-4dce-8f0a-1aa22e2463a3', '$2b$08$Z8Kk5XN4E5gndI0KWXW.nedwHt6mRpqdZwoIPABXP4v6qppyqhvgS', '2026-05-25 11:35:17', '2026-05-18 13:35:17'),
('3461d3ec-8426-4a67-bd5b-7a6c7fa5bf66', 'e31712c1-31b0-4e08-bd4b-57ded44b7f1a', '$2b$08$Eb.HxMsVzbhXREeBvxZFK.FItICZb6IwFlIkRqO8Z1Fl3PXvaOg.6', '2026-05-25 05:10:39', '2026-05-18 07:10:39'),
('39938fe2-4c8d-4c7c-bf54-3d781650e4b4', 'e1d71245-2709-4d3b-89f0-cdbd5baf18c5', '$2b$08$IQFYbskgzpKAPh/YlGJBheEICv6xvoIQUErB67e4n1wrukL.R4Eri', '2026-05-25 06:31:27', '2026-05-18 08:31:27'),
('43bc7e46-ffc9-4049-915f-1fe420f8f017', '4df044ab-55fb-4dce-8f0a-1aa22e2463a3', '$2b$08$WsgwgLSgLLf8EjExrOFtEuykumg95Eevy20anXY8uP.7ofJszdGDm', '2026-05-25 11:56:18', '2026-05-18 13:56:18'),
('534df985-ca61-468f-be53-15102acce645', '4df044ab-55fb-4dce-8f0a-1aa22e2463a3', '$2b$08$InbizQG/flrQOGpZlTWSFehwF17InOcxkJ5MA0fFnA1/P7Tb7/IzO', '2026-05-25 11:35:48', '2026-05-18 13:35:48'),
('66514291-cc01-4919-94ba-6144ab404673', '4df044ab-55fb-4dce-8f0a-1aa22e2463a3', '$2b$08$2i79NkFyARPBdmLG8mMlB.RrXAdZ.dtEveYUj5Ap.LYmpeqVf7RAG', '2026-05-25 10:32:17', '2026-05-18 12:32:17'),
('6a204783-c31b-4e0a-87d0-a89f9c79880a', '4df044ab-55fb-4dce-8f0a-1aa22e2463a3', '$2b$08$xaWifiyw.XvT0NsOdkoTtuLyLTDBlKuJ7PeUHWNpc3Rw2X6dXU3xy', '2026-05-25 10:26:10', '2026-05-18 12:26:10'),
('6e43c446-2774-49d6-a503-dd82709b9417', '4df044ab-55fb-4dce-8f0a-1aa22e2463a3', '$2b$08$Dq4pA05Kx7S7yVnZHjwoDeZwsJ9MwgpPdkNYKJ2NvQBp5Qh8FcGfS', '2026-05-25 10:45:45', '2026-05-18 12:45:45'),
('720784f9-5edd-4c1e-9df0-41a8580a4380', '4df044ab-55fb-4dce-8f0a-1aa22e2463a3', '$2b$08$D4GvoQCYgaZeNPeRqsfAEuXVOwn/okgz5AcyIzHheu6s3cTuhcTo6', '2026-05-25 10:32:14', '2026-05-18 12:32:14'),
('79c4f3c2-0d7a-4170-8571-73b94dd656d0', '4df044ab-55fb-4dce-8f0a-1aa22e2463a3', '$2b$08$raoy7rHK9vOeuzYBCt72geyN.sZWBavy/CQFEq6Smkx5R4FhBR6gK', '2026-05-25 10:47:07', '2026-05-18 12:47:07'),
('7abfe3cf-8fe7-4ddc-aad4-b93af60fbc32', '4df044ab-55fb-4dce-8f0a-1aa22e2463a3', '$2b$08$N1I4yBSNNMIl5sX/LKqxEetzWRMBbb0iyIM0p5SFtnBVB.3mzI4A2', '2026-05-25 10:46:57', '2026-05-18 12:46:57'),
('9627ab12-ff39-43ef-86ec-885aef9ea707', '4df044ab-55fb-4dce-8f0a-1aa22e2463a3', '$2b$08$qSi4tf8/QGaeBktyMbwmQ.VL5uIss4ZLG8iQylkCUPse9spaC07YW', '2026-05-25 10:22:00', '2026-05-18 12:22:00'),
('987e5dad-ffa2-463b-9e5a-f790d0ef41f7', '4df044ab-55fb-4dce-8f0a-1aa22e2463a3', '$2b$08$RN6dpHJnWAYTSkAgAEy.Dep2um/GSlOdphfe6m8bvMyWzPkmhdB2y', '2026-05-25 11:35:11', '2026-05-18 13:35:11'),
('99215a51-0779-4a49-964a-e497fdae774f', '4df044ab-55fb-4dce-8f0a-1aa22e2463a3', '$2b$08$bVX36w6DX1rIqX24S1nBWOoWqqOrS480ZOjqDmvJ.FaG8sqdWLceG', '2026-05-25 10:06:16', '2026-05-18 12:06:16'),
('accfefb0-2638-4c61-9668-e15a3f1c5633', '4df044ab-55fb-4dce-8f0a-1aa22e2463a3', '$2b$08$6z5euTQN1MOMzGR2yeQ/xum7aBr34E2M./b7nOBtvIrPAxXGD3PQe', '2026-05-25 12:14:20', '2026-05-18 14:14:20'),
('bca6705d-b2d0-4deb-840f-9b8099566352', '4df044ab-55fb-4dce-8f0a-1aa22e2463a3', '$2b$08$hGugu/Az9sx1BSf/f/QjQeHygSq.nCxoccAboyORQhI4QRJMVvzaK', '2026-05-25 11:37:05', '2026-05-18 13:37:05'),
('bfbbb26e-d61c-43f0-b184-5676a0de4581', '4df044ab-55fb-4dce-8f0a-1aa22e2463a3', '$2b$08$C3FPE3zUNGrlm8aA5j24euhDzJXMBLBeSXsLwgE5EePmkOQ3.f/fG', '2026-05-25 11:37:40', '2026-05-18 13:37:40'),
('c9895fb2-1a38-4e31-b772-4b2f99872dba', '4df044ab-55fb-4dce-8f0a-1aa22e2463a3', '$2b$08$QCwRj8B.gnFqiTvUwQC2mudyeOj39ajpOV3Z0r88A9b8.ZG2NaK5m', '2026-05-25 10:06:02', '2026-05-18 12:06:02'),
('d523d670-2451-4c86-b554-fb2b08497563', 'e1d71245-2709-4d3b-89f0-cdbd5baf18c5', '$2b$08$T0namIYgUBIBMk8hVmKRu.kVUQ75JBsRPGjm5zsIN65tL2MUh5nmO', '2026-05-25 11:41:29', '2026-05-18 13:41:29'),
('dc53e5ef-791b-49b6-968a-9552e50c4b47', '4df044ab-55fb-4dce-8f0a-1aa22e2463a3', '$2b$08$irE8sYUz69BPM5lAYlRV3u4Sny2Qwa1Kc7yFk7hzRdQ7NFCA4WbEG', '2026-05-25 11:43:21', '2026-05-18 13:43:21'),
('dc6ff8f4-3bca-46da-9bcb-2da3984a1356', '4df044ab-55fb-4dce-8f0a-1aa22e2463a3', '$2b$08$lIN7i/d2RvztUrsxztfOiOMnWsyJTnZrUALy9cC84iTeEe1CHm3wi', '2026-05-25 12:23:07', '2026-05-18 14:23:07'),
('ddfb0766-c382-49d2-9c01-8ee9222648bc', 'e31712c1-31b0-4e08-bd4b-57ded44b7f1a', '$2b$08$wu5skgmp8WiXaTYT4LQM8.UY34CXHjhqj3FGwygXCTcOZdW.umVme', '2026-05-25 05:10:50', '2026-05-18 07:10:50'),
('f2303f75-d0ea-4562-967d-6e1409e1f962', 'e31712c1-31b0-4e08-bd4b-57ded44b7f1a', '$2b$08$0WQqnTEG.sNgwjWsGgrk2umRfba74wKDVfiXhNVadgxAFm4A/Q66O', '2026-05-25 05:10:50', '2026-05-18 07:10:50'),
('f39f5f1a-5ad2-43cb-af61-43d6bd076e31', '4df044ab-55fb-4dce-8f0a-1aa22e2463a3', '$2b$08$wgwOKDpf9x.IMRE16iGJ1uuHbzKTs8bPDAB7hBhQMjRc2QBz7Vv9q', '2026-05-25 10:17:31', '2026-05-18 12:17:31'),
('f6f7c7d5-bb75-46e6-8030-b20c9c31c65c', '4df044ab-55fb-4dce-8f0a-1aa22e2463a3', '$2b$08$3EyJY/vlJVnKgzHsSEAroumRMbMOwQiTLM1ZeWjIJFTDlaeymmyEm', '2026-05-25 11:51:51', '2026-05-18 13:51:51'),
('f7d40531-1980-4c6c-9117-f525edd304f5', '4df044ab-55fb-4dce-8f0a-1aa22e2463a3', '$2b$08$stvsepTmDNi0X.s5KmhnE.h..x1i1t8iuRcSenMbeIWdpO9Ne/1/u', '2026-05-25 12:14:14', '2026-05-18 14:14:14');

-- --------------------------------------------------------

--
-- Table structure for table `users`
--

CREATE TABLE `users` (
  `id` varchar(36) NOT NULL,
  `full_name` varchar(255) NOT NULL,
  `email` varchar(255) NOT NULL,
  `password_hash` varchar(255) NOT NULL,
  `role` enum('admin','lecturer','student') NOT NULL DEFAULT 'student',
  `reg_number` varchar(50) DEFAULT NULL,
  `phone` varchar(20) DEFAULT NULL,
  `department` varchar(100) DEFAULT NULL,
  `is_active` tinyint(1) NOT NULL DEFAULT 1,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `users`
--

INSERT INTO `users` (`id`, `full_name`, `email`, `password_hash`, `role`, `reg_number`, `phone`, `department`, `is_active`, `created_at`, `updated_at`) VALUES
('266e8693-1e0f-4fe3-b671-9ced002ba333', 'Grace UWASE', 'grace@stud.ur.ac.rw', '$2b$12$Tpg2P1Sqk2ZyLaiQREB4fOdCDn7Vy6OUzE9IcbxsVs8BZidJxKgDa', 'student', '223008050', NULL, 'Mathematics', 1, '2026-05-18 07:08:30', '2026-05-18 07:08:30'),
('321fea50-3cc9-462a-87a6-f14aa3f1901a', 'System Administrator', 'admin@attendx.edu', '$2b$12$bVlB.tJGJXYLc.gIB3AdruBVfFeNb8GLhuT6EzOulGnVu31M42yBK', 'admin', NULL, NULL, 'Administration', 1, '2026-05-18 07:08:30', '2026-05-18 07:08:30'),
('34dd7b87-b27b-4df2-a369-8efc52fff6b9', 'Alice UMURERWA', 'alice2@stud.ur.ac.rw', '$2b$12$Tpg2P1Sqk2ZyLaiQREB4fOdCDn7Vy6OUzE9IcbxsVs8BZidJxKgDa', 'student', '223008052', NULL, 'Computer Science', 1, '2026-05-18 07:08:30', '2026-05-18 07:08:30'),
('4df044ab-55fb-4dce-8f0a-1aa22e2463a3', 'HAKUZWIMANA silas', 'hakusilas@gmail.com', '$2b$12$VMooYCb7isSZQP85DCq67eKrq6ievGOf2STHvMe/H.uiCbaHJYPn.', 'student', NULL, NULL, 'Computer Science', 1, '2026-05-18 08:36:47', '2026-05-18 08:36:47'),
('a90b9218-39e4-4956-8461-1454c5b08e79', 'Patrick MUGISHA', 'patrick@stud.ur.ac.rw', '$2b$12$Tpg2P1Sqk2ZyLaiQREB4fOdCDn7Vy6OUzE9IcbxsVs8BZidJxKgDa', 'student', '223008051', NULL, 'Computer Science', 1, '2026-05-18 07:08:30', '2026-05-18 07:08:30'),
('a96a00af-db35-4808-8fd1-d3c8ccdfa7a8', 'Dr. Bob Nkurunziza', 'bob@ur.ac.rw', '$2b$12$kDkq7cU/VB0evNykAVZQAekciBv6.s8sJatsNouvhzPF3vqXhOyI2', 'lecturer', NULL, NULL, 'Mathematics', 1, '2026-05-18 07:08:30', '2026-05-18 07:08:30'),
('e1d71245-2709-4d3b-89f0-cdbd5baf18c5', 'Dr. Alice Uwimana', 'alice@ur.ac.rw', '$2b$12$kDkq7cU/VB0evNykAVZQAekciBv6.s8sJatsNouvhzPF3vqXhOyI2', 'lecturer', NULL, NULL, 'Computer Science', 1, '2026-05-18 07:08:30', '2026-05-18 07:08:30'),
('e31712c1-31b0-4e08-bd4b-57ded44b7f1a', 'Fabrice NDAYISABA', 'fabrice@stud.ur.ac.rw', '1234', 'student', '223008047', NULL, 'Computer Science', 1, '2026-05-18 07:08:30', '2026-05-18 07:08:30'),
('fb4e8926-e40f-4afa-af86-418e041830aa', 'Marie INGABIRE', 'marie@stud.ur.ac.rw', '$2b$12$Tpg2P1Sqk2ZyLaiQREB4fOdCDn7Vy6OUzE9IcbxsVs8BZidJxKgDa', 'student', '223008048', NULL, 'Computer Science', 1, '2026-05-18 07:08:30', '2026-05-18 07:08:30'),
('fbb4f2cf-5882-4af4-aef0-4c2511abac82', 'Jean HAKIZIMANA', 'jean@stud.ur.ac.rw', '$2b$12$Tpg2P1Sqk2ZyLaiQREB4fOdCDn7Vy6OUzE9IcbxsVs8BZidJxKgDa', 'student', '223008049', NULL, 'Computer Science', 1, '2026-05-18 07:08:30', '2026-05-18 07:08:30');

--
-- Indexes for dumped tables
--

--
-- Indexes for table `attendance_records`
--
ALTER TABLE `attendance_records`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `uq_session_student` (`session_id`,`student_id`),
  ADD KEY `fk_rec_student` (`student_id`);

--
-- Indexes for table `attendance_sessions`
--
ALTER TABLE `attendance_sessions`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `uq_session_code` (`session_code`),
  ADD KEY `fk_sess_course` (`course_id`),
  ADD KEY `fk_sess_classroom` (`classroom_id`),
  ADD KEY `fk_sess_lecturer` (`lecturer_id`);

--
-- Indexes for table `classrooms`
--
ALTER TABLE `classrooms`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `courses`
--
ALTER TABLE `courses`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `uq_courses_code` (`code`),
  ADD KEY `fk_courses_lecturer` (`lecturer_id`);

--
-- Indexes for table `device_tokens`
--
ALTER TABLE `device_tokens`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `uq_user_platform` (`user_id`,`platform`);

--
-- Indexes for table `enrollments`
--
ALTER TABLE `enrollments`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `uq_enrollment` (`student_id`,`course_id`),
  ADD KEY `fk_enroll_course` (`course_id`);

--
-- Indexes for table `notifications`
--
ALTER TABLE `notifications`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_notif_user` (`user_id`);

--
-- Indexes for table `notification_preferences`
--
ALTER TABLE `notification_preferences`
  ADD PRIMARY KEY (`user_id`);

--
-- Indexes for table `password_reset_tokens`
--
ALTER TABLE `password_reset_tokens`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `uq_prt_token` (`token`),
  ADD KEY `fk_prt_user` (`user_id`);

--
-- Indexes for table `refresh_tokens`
--
ALTER TABLE `refresh_tokens`
  ADD PRIMARY KEY (`id`),
  ADD KEY `fk_rt_user` (`user_id`);

--
-- Indexes for table `users`
--
ALTER TABLE `users`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `uq_users_email` (`email`);

--
-- Constraints for dumped tables
--

--
-- Constraints for table `attendance_records`
--
ALTER TABLE `attendance_records`
  ADD CONSTRAINT `fk_rec_session` FOREIGN KEY (`session_id`) REFERENCES `attendance_sessions` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `fk_rec_student` FOREIGN KEY (`student_id`) REFERENCES `users` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `attendance_sessions`
--
ALTER TABLE `attendance_sessions`
  ADD CONSTRAINT `fk_sess_classroom` FOREIGN KEY (`classroom_id`) REFERENCES `classrooms` (`id`),
  ADD CONSTRAINT `fk_sess_course` FOREIGN KEY (`course_id`) REFERENCES `courses` (`id`),
  ADD CONSTRAINT `fk_sess_lecturer` FOREIGN KEY (`lecturer_id`) REFERENCES `users` (`id`);

--
-- Constraints for table `courses`
--
ALTER TABLE `courses`
  ADD CONSTRAINT `fk_courses_lecturer` FOREIGN KEY (`lecturer_id`) REFERENCES `users` (`id`) ON DELETE SET NULL;

--
-- Constraints for table `device_tokens`
--
ALTER TABLE `device_tokens`
  ADD CONSTRAINT `fk_dt_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `enrollments`
--
ALTER TABLE `enrollments`
  ADD CONSTRAINT `fk_enroll_course` FOREIGN KEY (`course_id`) REFERENCES `courses` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `fk_enroll_student` FOREIGN KEY (`student_id`) REFERENCES `users` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `notifications`
--
ALTER TABLE `notifications`
  ADD CONSTRAINT `fk_notif_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `notification_preferences`
--
ALTER TABLE `notification_preferences`
  ADD CONSTRAINT `fk_np_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `password_reset_tokens`
--
ALTER TABLE `password_reset_tokens`
  ADD CONSTRAINT `fk_prt_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `refresh_tokens`
--
ALTER TABLE `refresh_tokens`
  ADD CONSTRAINT `fk_rt_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
