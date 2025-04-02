import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class SkeletonChatBubble extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Align(
      // You can adjust the alignment if needed.
      alignment: Alignment.centerLeft,
      child: Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: Container(
          margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(0),
              topRight: Radius.circular(12),
              bottomLeft: Radius.circular(12),
              bottomRight: Radius.circular(12),
            ),          
          ),
          width: 180,
          height: 40, 
        ),
      ),
    );
  }
}
