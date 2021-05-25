import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mapo/services/firebase_auth_services.dart';

final realTimeServices = Provider<FirebaseRealTimeServices>((ref) {
  final user = ref.watch(authServicesProvider).getCurrentUser();
  return FirebaseRealTimeServices(user!.uid);
});

// final realTimeStreamProvider =
//     StreamProvider.autoDispose.family<dynamic, String>((ref, albumId) {
//   final service = ref.read(realTimeServices);
//   return service.albumStream(albumId);
// });

class FirebaseRealTimeServices {
  final String uid;
  FirebaseDatabase database = FirebaseDatabase(
    databaseURL:
        "https://mapo-9abd3-default-rtdb.asia-southeast1.firebasedatabase.app",
  );
  FirebaseRealTimeServices(this.uid) {
    database.setPersistenceEnabled(true);
    database.setPersistenceCacheSizeBytes(10000000);
    ref = database.reference().child("timetrace");
  }

  late DatabaseReference ref;

  // albumStream(String albumId) {
  //   print(albumId);
  //   ref.child(albumId).once().then((element) {
  //     print(element.value.toString());
  //   });
  //   // print(ref.child(albumId).onValue);
  //   return ref.child(albumId).onValue;
  // }

  Future<Map<String, int>> userAlbumsStream() {
    return ref
        .orderByChild("owner")
        .equalTo(uid)
        .once()
        .then((DataSnapshot data) {
      int tLike = 0;
      int tRead = 0;
      int tAlbum = data.value.entries.length;
      for (var item in data.value.entries) {
        int l = item.value["likecount"];
        int r = item.value["readcount"];
        tLike += l;
        tRead += r;
      }
      return {
        "tLike": tLike,
        "tRead": tRead,
        "tAlbum": tAlbum,
      };
    });
  }

  void insertCard(String albumId) {
    ref.child(albumId).set({
      'owner': this.uid,
      'likecount': 0,
      'readcount': 0,
      '${this.uid}': true,
    }).then((value) => print("success!"));
  }

  Future<void> onReadClicked(String albumId) async {
    await ref.child(albumId).runTransaction((MutableData data) async {
      var item = data.value;
      if (item['owner'] != uid) {
        item['readcount'] = item['readcount'] + 1;
      }
      return data;
    });
  }

  Future<void> onLikeClicked(String albumId) async {
    await ref.child(albumId).runTransaction((MutableData data) async {
      var item = data.value;
      if (item['owner'] != uid) {
        var user = item['$uid'] ?? false;
        if (user) {
          item['likecount'] = item['likecount'] - 1;
          item['$uid'] = false;
        } else {
          item['likecount'] = item['likecount'] + 1;
          item['$uid'] = true;
        }
      }
      return data;
    });
  }

  void delete(String albumId) {
    ref.child(albumId).remove();
  }
}
