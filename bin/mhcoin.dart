import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

void main(List<String> arguments) {
  print('MHCoin Miner by akella122');

  stdout.write('username: ');
  var username = stdin.readLineSync();

  stdout.write('low difficult? (y/N): ');
  var answer = stdin.readLineSync().toLowerCase();
  var lowerDiff = false;
  if (answer.contains('y')) lowerDiff = true;
  Miner().process(username, lowerDiff);
}

class Miner {
  String result, difficult;
  bool lowerDiff;

  Future<void> process(String username, bool lowerDiff) async {
    var response = await Dio().get('https://mhcoin.s3.filebase.com/Pool.txt');
    var adress = response.data.toString().split('\n');
    var isFirst = true;
    var waitFeedback = false;
    var counter = 0;
    var time;
    this.lowerDiff = lowerDiff;

    final socket = await Socket.connect(adress[0], int.parse(adress[1].trim()));
    print('Connected to: ${socket.remoteAddress.address}:${socket.remotePort}');

    // listen for responses from the server
    socket.listen(
      (Uint8List data) {
        final serverResponse = String.fromCharCodes(data);
        if (isFirst) {
          print('Server version: $serverResponse');
          isFirst = false;
        } else {
          //print('Server: $serverResponse');
          if (waitFeedback) {
            counter++;
            time = DateTime.now().hour.toString() +
                ':' +
                DateTime.now().minute.toString() +
                ':' +
                DateTime.now().second.toString();
            if (serverResponse == 'GOOD') {
              print(
                  '[$counter][Accepted] Time: $time, result: $result, difficult: $difficult');
            } else if (serverResponse == 'BAD') {
              print(
                  '[$counter][Rejected] Result: $result, difficult: $difficult');
            }
            waitFeedback = false;
            getJob(socket, username);
          } else {
            workJob(socket, serverResponse.split(','));
            waitFeedback = true;
          }
        }
      },
      onError: (error) {
        print(error);
        socket.destroy();
      },
      onDone: () {
        print('Server left.');
        socket.destroy();
      },
    );

    await getJob(socket, username);
  }

  Future<void> getJob(Socket socket, String username) async {
    if (lowerDiff) {
      socket.write('JOB,$username,MEDIUM');
    } else {
      socket.write('JOB,$username');
    }
  }

  Future<void> workJob(Socket socket, List<String> job) async {
    var n = 100 * int.parse(job[2]) + 1;
    difficult = job[2];
    for (var i = 0; i <= n; i++) {
      var bytes = utf8.encode(job[0] + i.toString());
      var digest = sha1.convert(bytes);
      if (digest.toString() == job[1]) {
        result = i.toString();
        socket.write(result);
        break;
      }
    }
  }
}
