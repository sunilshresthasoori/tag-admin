import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../services/auth_service.dart';

part 'auth_event.dart';
part 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthService _authService;

  AuthBloc(this._authService) : super(const AuthState()) {
    on<LoginRequested>(_onLoginRequested);
    on<LogoutRequested>(_onLogoutRequested);
    on<CheckAuthStatus>(_onCheckAuthStatus);
  }

  Future<void> _onLoginRequested(LoginRequested event, Emitter<AuthState> emit) async {
    emit(state.copyWith(status: AuthStatus.loading));
    try {
      final success = await _authService.login(event.username, event.password);
      if (success) {
        emit(state.copyWith(status: AuthStatus.authenticated));
      } else {
        emit(state.copyWith(status: AuthStatus.failure, errorMessage: 'Invalid username or password'));
      }
    } catch (e) {
      emit(state.copyWith(status: AuthStatus.failure, errorMessage: e.toString()));
    }
  }

  Future<void> _onLogoutRequested(LogoutRequested event, Emitter<AuthState> emit) async {
    await _authService.logout();
    emit(state.copyWith(status: AuthStatus.unauthenticated));
  }

  Future<void> _onCheckAuthStatus(CheckAuthStatus event, Emitter<AuthState> emit) async {
    final token = await _authService.getAccessToken();
    if (token != null) {
      emit(state.copyWith(status: AuthStatus.authenticated));
    } else {
      emit(state.copyWith(status: AuthStatus.unauthenticated));
    }
  }
}
