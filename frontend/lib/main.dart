import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

import 'features/verification/data/datasources/verification_remote_datasource.dart';
import 'features/verification/data/repositories/verification_repository_impl.dart';
import 'features/verification/domain/usecases/upload_and_predict.dart';
import 'features/verification/presentation/bloc/verification_bloc.dart';
import 'features/verification/presentation/pages/inference_page.dart';
import 'features/verification/presentation/styles/app_colors.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<VerificationRemoteDataSource>(
          create: (_) => VerificationRemoteDataSource(client: http.Client()),
        ),
        RepositoryProvider<VerificationRepositoryImpl>(
          create: (context) => VerificationRepositoryImpl(
            remoteDataSource: context.read<VerificationRemoteDataSource>(),
          ),
        ),
      ],
      child: BlocProvider(
        create: (context) => VerificationBloc(
          uploadAndPredict: UploadAndPredict(
            context.read<VerificationRepositoryImpl>(),
          ),
        ),
        child: MaterialApp(
          title: 'SmartChecker',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
            appBarTheme: const AppBarTheme(
              backgroundColor: AppColors.darkBackground,
              foregroundColor: Colors.white,
              centerTitle: true,
            ),
            textTheme: GoogleFonts.interTextTheme(),
            visualDensity: VisualDensity.adaptivePlatformDensity,
          ),
          home: const InferencePage(),
        ),
      ),
    );
  }
}
