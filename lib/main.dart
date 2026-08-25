import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'screens/rfid_scanner_page.dart';
import 'screens/login_page.dart';
import 'services/auth_service.dart';
import 'blocs/auth/auth_bloc.dart';
import 'services/rfid_service.dart';
import 'services/scan_storage_service.dart';
import 'services/api_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider(create: (context) => AuthService()),
        RepositoryProvider(create: (context) => RFIDService()),
        RepositoryProvider(create: (context) => ScanStorageService()),
        RepositoryProvider(create: (context) => ApiService()),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (context) => AuthBloc(context.read<AuthService>())..add(CheckAuthStatus()),
          ),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Tag Admin',
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
            useMaterial3: true,
          ),
          home: BlocBuilder<AuthBloc, AuthState>(
            builder: (context, state) {
              if (state.status == AuthStatus.authenticated) {
                return const RFIDScannerPage();
              }
              if (state.status == AuthStatus.loading || state.status == AuthStatus.initial) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              return const LoginPage();
            },
          ),
        ),
      ),
    );
  }
}
