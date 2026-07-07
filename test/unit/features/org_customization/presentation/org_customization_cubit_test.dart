import 'package:ataulfo/features/memberships/domain/entities/membership.dart';
import 'package:ataulfo/features/memberships/domain/repositories/memberships_repository.dart';
import 'package:ataulfo/features/org_customization/domain/entities/org_branding.dart';
import 'package:ataulfo/features/org_customization/domain/failures/org_branding_failure.dart';
import 'package:ataulfo/features/org_customization/domain/repositories/org_branding_repository.dart';
import 'package:ataulfo/features/org_customization/presentation/bloc/org_customization_cubit.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockBrandingRepo extends Mock implements OrgBrandingRepository {}

class _MockMembershipsRepo extends Mock implements MembershipsRepository {}

const _base = OrgBranding(
  configured: false,
  customTex: false,
  hasLogo: false,
  logoUrl: '',
  logoContentType: '',
);

const _withLogo = OrgBranding(
  configured: true,
  customTex: false,
  hasLogo: true,
  logoUrl: 'https://signed/l1',
  logoContentType: 'image/png',
);

const _members = <Membership>[
  Membership(orgId: 'org-1', orgName: 'App Master', role: 'OWNER'),
  Membership(orgId: 'org-2', orgName: 'Otra', role: 'WORKER'),
];

void main() {
  late _MockBrandingRepo branding;
  late _MockMembershipsRepo memberships;

  setUp(() {
    branding = _MockBrandingRepo();
    memberships = _MockMembershipsRepo();
  });

  OrgCustomizationCubit build() => OrgCustomizationCubit(
    branding: branding,
    memberships: memberships,
    activeOrgId: 'org-1',
  );

  group('load', () {
    blocTest<OrgCustomizationCubit, OrgCustomizationState>(
      'marca + nombre de la org activa → Ready',
      build: () {
        when(() => branding.get()).thenAnswer((_) async => _base);
        when(() => memberships.list()).thenAnswer((_) async => _members);
        return build();
      },
      act: (c) => c.load(),
      expect: () => <OrgCustomizationState>[
        const OrgCustomizationLoading(),
        const OrgCustomizationReady(orgName: 'App Master', branding: _base),
      ],
    );

    blocTest<OrgCustomizationCubit, OrgCustomizationState>(
      'memberships caído → Ready con nombre vacío (best-effort)',
      build: () {
        when(() => branding.get()).thenAnswer((_) async => _withLogo);
        when(
          () => memberships.list(),
        ).thenThrow(Exception('memberships caído'));
        return build();
      },
      act: (c) => c.load(),
      expect: () => <OrgCustomizationState>[
        const OrgCustomizationLoading(),
        const OrgCustomizationReady(orgName: '', branding: _withLogo),
      ],
    );

    blocTest<OrgCustomizationCubit, OrgCustomizationState>(
      'branding caído → Error (sin marca no hay módulo)',
      build: () {
        when(() => branding.get()).thenThrow(const OrgBrandingServerFailure());
        when(() => memberships.list()).thenAnswer((_) async => _members);
        return build();
      },
      act: (c) => c.load(),
      expect: () => <OrgCustomizationState>[
        const OrgCustomizationLoading(),
        const OrgCustomizationError(OrgBrandingServerFailure()),
      ],
    );
  });

  group('setLogo', () {
    blocTest<OrgCustomizationCubit, OrgCustomizationState>(
      'guarda y recarga la marca fresca',
      build: () {
        when(
          () => branding.setLogo('tenant/org-1/media/l1.png'),
        ).thenAnswer((_) async {});
        when(() => branding.get()).thenAnswer((_) async => _withLogo);
        return build();
      },
      seed: () =>
          const OrgCustomizationReady(orgName: 'App Master', branding: _base),
      act: (c) => c.setLogo('tenant/org-1/media/l1.png'),
      expect: () => <OrgCustomizationState>[
        const OrgCustomizationReady(
          orgName: 'App Master',
          branding: _base,
          saving: true,
        ),
        const OrgCustomizationReady(orgName: 'App Master', branding: _withLogo),
      ],
      verify: (_) {
        verify(() => branding.setLogo('tenant/org-1/media/l1.png')).called(1);
      },
    );

    blocTest<OrgCustomizationCubit, OrgCustomizationState>(
      'fallo del PUT → Ready con mutationFailure (la marca previa se queda)',
      build: () {
        when(
          () => branding.setLogo(any()),
        ).thenThrow(const OrgBrandingInvalidFailure());
        return build();
      },
      seed: () =>
          const OrgCustomizationReady(orgName: 'App Master', branding: _base),
      act: (c) => c.setLogo('tenant/org-1/media/x.gif'),
      expect: () => <OrgCustomizationState>[
        const OrgCustomizationReady(
          orgName: 'App Master',
          branding: _base,
          saving: true,
        ),
        const OrgCustomizationReady(
          orgName: 'App Master',
          branding: _base,
          mutationFailure: OrgBrandingInvalidFailure(),
        ),
      ],
    );
  });

  group('reset', () {
    blocTest<OrgCustomizationCubit, OrgCustomizationState>(
      'borra la marca y recarga el estado base',
      build: () {
        when(() => branding.reset()).thenAnswer((_) async {});
        when(() => branding.get()).thenAnswer((_) async => _base);
        return build();
      },
      seed: () => const OrgCustomizationReady(
        orgName: 'App Master',
        branding: _withLogo,
      ),
      act: (c) => c.reset(),
      expect: () => <OrgCustomizationState>[
        const OrgCustomizationReady(
          orgName: 'App Master',
          branding: _withLogo,
          saving: true,
        ),
        const OrgCustomizationReady(orgName: 'App Master', branding: _base),
      ],
    );
  });
}
