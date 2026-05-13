import { AbstractWidgetComponent } from 'core-app/shared/components/grids/widgets/abstract-widget.component';
import { ChangeDetectionStrategy, ChangeDetectorRef, Component, HostBinding, OnInit, ViewEncapsulation, inject } from '@angular/core';
import { HalResourceService } from 'core-app/features/hal/services/hal-resource.service';
import { PathHelperService } from 'core-app/core/path-helper/path-helper.service';
import { CurrentProjectService } from 'core-app/core/current-project/current-project.service';
import { ProjectResource } from 'core-app/features/hal/resources/project-resource';
import { ApiV3Service } from 'core-app/core/apiv3/api-v3.service';
import { TimezoneService } from 'core-app/core/datetime/timezone.service';
import { ApiV3FilterBuilder } from 'core-app/shared/helpers/api-v3/api-v3-filter-builder';
import { Observable } from 'rxjs';

@Component({
  templateUrl: './widget-project-favorites.component.html',
  styleUrls: ['./widget-project-favorites.component.sass'],
  encapsulation: ViewEncapsulation.None,
  changeDetection: ChangeDetectionStrategy.OnPush,
  standalone: false,
})
export class WidgetProjectFavoritesComponent extends AbstractWidgetComponent implements OnInit {
  readonly halResource = inject(HalResourceService);
  readonly pathHelper = inject(PathHelperService);
  readonly timezone = inject(TimezoneService);
  readonly apiV3Service = inject(ApiV3Service);
  readonly currentProject = inject(CurrentProjectService);
  readonly cdr = inject(ChangeDetectorRef);

  @HostBinding('class.op-widget-project-favorites') className = true;

  public text = {
    no_favorites: this.i18n.t('js.favorite_projects.no_results'),
    no_favorites_subtext: this.i18n.t('js.favorite_projects.no_results_subtext'),
  };

  public projects$:Observable<ProjectResource[]>;

  ngOnInit() {
    const filters = new ApiV3FilterBuilder();
    filters.add('favorited', '=', true);
    filters.add('active', '=', true);

    this.projects$ = this
      .apiV3Service
      .projects
      .filtered(filters, { sortBy: '[["name","asc"]]', pageSize: '-1' })
      .getPaginatedResults();
  }

  projectPath(project:ProjectResource) {
    return this.pathHelper.projectPath(project.identifier);
  }
}
