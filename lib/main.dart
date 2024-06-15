import 'dart:convert';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:zoom_auth_token_generator/config.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const GenerateTokens(),
    );
  }
}

class GenerateTokens extends StatelessWidget {
  const GenerateTokens({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            // GEt Oauth Token ------------------------------------------

            var url = Uri.https('zoom.us', '/oauth/token');
            var response = await http.post(
              url,
              headers: {
                'Content-Type': 'application/x-www-form-urlencoded',
                'Authorization': 'Basic $kBase64Key',
              },
              body: {
                'grant_type': 'account_credentials',
                'account_id': s2sAccountId,
              },
            );

            // This might be required for user auth, but definitely not required for server to server oauth
            // var url = Uri.parse(
            //     "https://zoom.us/oauth/token?grant_type=account_credentials&account_id=$kAccountId");

            // var response = await http.post(
            //   url,
            //   headers: {
            //     'Authorization': 'Basic $kBase64Key',
            //   },
            //   body: {'client_id': kZoomMeetingSdkKey},
            // );

            debugPrint('Response status: ${response.statusCode}');
            // debugPrint('Response body: ${response.body}');

            final accessTokenRes = jsonDecode(response.body);
            final accessToken = accessTokenRes['access_token'];

            debugPrint("");
            debugPrint("Access Token :$accessToken", wrapWidth: 800);

            //

            // Getting ZAK Token ----------------------------------------

            //

            final zakUrl =
                Uri.parse("https://api.zoom.us/v2/users/me/token?type=zak");
            final options = {
              "Authorization": "Bearer $accessToken",
              // "Content-Type": "application/json",
            };

            final zakResponse = await http.get(zakUrl, headers: options);

            final zakToken = jsonDecode(zakResponse.body);

            debugPrint("");
            debugPrint("ZAK Token :$zakToken", wrapWidth: 800);

            //

            // Getting Meeting Details ----------------------------------

            //

            var meetingUrl = Uri.https('api.zoom.us', '/v2/users/me/meetings');
            var responseMeeting = await http.post(
              meetingUrl,
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $accessToken',
              },
              body: jsonEncode(
                {
                  // Take Input from User
                  "topic": "My New Meeting",
                  "type": 2,
                  "start_time": "2024-06-13T12:20:00Z",
                  "duration": 60,
                  "password": "123456",
                  "timezone": "UTC",
                  "settings": {"auto_recording": "cloud"}
                },
              ),
            );

            debugPrint('Response status: ${responseMeeting.statusCode}');
            // debugPrint('Response body: ${responseMeeting.body}');

            final meeting = jsonDecode(responseMeeting.body);

            debugPrint("");
            debugPrint("Meeting Details: $meeting");

            //

            // JWT Signature --------------------------------------------

            //

            final meetingNum = meeting['id'];

            debugPrint(
                "Meeting ID: $meetingNum, Type: ${meetingNum.runtimeType}");

            final header = {'alg': 'HS256', 'typ': 'JWT'};
            final payload = {
              'sdkKey': meetingSDKClientId,
              'appKey': meetingSDKClientId,
              'iat':
                  (DateTime.now().millisecondsSinceEpoch / 1000).floor() - 30,
              'exp': (DateTime.now().millisecondsSinceEpoch / 1000).floor() +
                  (60 * 60 * 6), // 6 Hours expiration
              'role': 1, // If role is Host, use 1; otherwise, use 0
              'tokenExp':
                  (DateTime.now().millisecondsSinceEpoch / 1000).floor() +
                      (60 * 60 * 6), // 6 Hours expiration
              'mn': meetingNum, // Nullable Meeting ID
            };

            final jwt = JWT(payload, header: header);
            final secretKey = SecretKey(meetingSDKClientSecret);

            final jwtToken = jwt.sign(secretKey, algorithm: JWTAlgorithm.HS256);

            debugPrint("");
            debugPrint("JWT SIGN: $jwtToken");
          },
          child: const Text("Generate Access Token"),
        ),
      ),
    );
  }
}
