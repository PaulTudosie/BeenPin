import 'package:been/models/social_user.dart';

/// The local Journey profile. Replace this source when sign-in is introduced.
class CurrentUserProfile {
  static const user = SocialUser(
    id: 'camil',
    name: 'Camil',
    city: 'Bucharest, Romania',
    levelName: 'Walker',
    handle: '@camil.frames',
    avatarPath: null,
    tagline: 'Quiet city corners, street textures, and coffee-fuelled walks.',
  );

  static SocialUser snapshot({String? avatarPath}) => SocialUser(
        id: user.id,
        name: user.name,
        city: user.city,
        levelName: user.levelName,
        handle: user.handle,
        avatarPath: avatarPath,
        tagline: user.tagline,
      );
}
