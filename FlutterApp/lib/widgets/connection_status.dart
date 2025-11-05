import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/irrigation_provider.dart';

/// Widget to display backend and WebSocket connection status
class ConnectionStatusWidget extends StatelessWidget {
  const ConnectionStatusWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<IrrigationProvider>(
      builder: (context, provider, child) {
        final isBackendConnected = provider.isBackendConnected;
        final isWebSocketConnected = provider.isWebSocketConnected;
        
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isBackendConnected 
              ? const Color(0xFF10B981).withOpacity(0.1)
              : const Color(0xFFEF4444).withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isBackendConnected 
                ? const Color(0xFF10B981)
                : const Color(0xFFEF4444),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Backend Status Indicator
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: isBackendConnected 
                    ? const Color(0xFF10B981)
                    : const Color(0xFFEF4444),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              
              // Status Text
              Text(
                isBackendConnected 
                  ? (isWebSocketConnected ? 'Live' : 'Connected') 
                  : 'Offline',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isBackendConnected 
                    ? const Color(0xFF10B981)
                    : const Color(0xFFEF4444),
                ),
              ),
              
              // WebSocket Indicator (if backend connected)
              if (isBackendConnected) ...[
                const SizedBox(width: 8),
                Icon(
                  isWebSocketConnected 
                    ? Icons.wifi 
                    : Icons.wifi_off,
                  size: 14,
                  color: isWebSocketConnected
                    ? const Color(0xFF10B981)
                    : const Color(0xFF6B7280),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// Compact connection indicator (just a dot)
class ConnectionIndicator extends StatelessWidget {
  const ConnectionIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<IrrigationProvider>(
      builder: (context, provider, child) {
        final isConnected = provider.isBackendConnected;
        
        return Tooltip(
          message: isConnected ? 'Backend Connected' : 'Backend Offline',
          child: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: isConnected 
                ? const Color(0xFF10B981)
                : const Color(0xFFEF4444),
              shape: BoxShape.circle,
              boxShadow: isConnected ? [
                BoxShadow(
                  color: const Color(0xFF10B981).withOpacity(0.5),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ] : null,
            ),
          ),
        );
      },
    );
  }
}

